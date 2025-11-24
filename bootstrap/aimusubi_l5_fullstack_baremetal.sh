#!/usr/bin/env bash
# AIMusubi L5 — Unified Full Stack Bootstrap (Core + L5 API + Prometheus + Grafana + Open WebUI + OPA)
# Installs and configures the entire AIMusubi stack on bare-metal via bash.
# Date: 2025-11-15, Version 1.0
set -euo pipefail

# Ensure Debian/Ubuntu (apt-based) system
if ! [ -f /etc/debian_version ]; then
  echo "[ERROR] This script is designed for Debian-based systems (like Ubuntu) that use 'apt'."
  echo "[ERROR] Your system does not appear to be supported. Aborting."
  exit 1
fi

# Ensure running as root
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[ERROR] This script must be run as root."
  echo "        Try: sudo ./aimusubi_l5_fullstack_baremetal.sh"
  exit 1
fi

echo "====================================================================="
echo " AIMusubi L5 — Unified Full Stack Bootstrap (Bare-Metal)"
echo "====================================================================="
echo
echo "This script will:"
echo "  - Add the Grafana APT repository."
echo "  - Install system packages via apt (Prometheus, Grafana, Python, nmap, etc.)."
echo "  - Install Ollama and pull the llama3 model."
echo "  - Create Python virtual environments under \$AIMusubi_HOME."
echo "  - Install Python packages via pip."
echo "  - Generate AIMusubi API, adapter manifests, and configs."
echo "  - Create and enable multiple systemd services."
echo
echo "  - This build supports multi-vendor NetOps: Cisco IOS-XE, Arista EOS, and VyOS."
echo "  - Unified intent engine across all vendors."
echo
echo "This project represents hundreds of hours of work to advance agentic operations."
echo "If this helps you learn, build, or think differently — that’s the mission."
echo "— AIMusubi Project"
echo
read -p 'Do you want to proceed with the installation? (y/N) ' -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Installation cancelled."
  exit 0
fi

# ---------- Basic paths ----------
USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
AIMusubi_HOME="${AIMusubi_HOME:-$USER_HOME/AIMusubi}"

CORE_DIR="$AIMusubi_HOME/core"
PKG_DIR="$CORE_DIR/AIMusubi"
ADAPT_DIR="$AIMusubi_HOME/adapters"
TOOLS_DIR="$AIMusubi_HOME/tools"
TASKS_DIR="$AIMusubi_HOME/tasks"
LOG_DIR="$AIMusubi_HOME/logs"
VENV_DIR="$CORE_DIR/venv"

OPENWEBUI_DIR="$AIMusubi_HOME/open-webui"
OPENWEBUI_VENV="$OPENWEBUI_DIR/venv"

API_PORT="${API_PORT:-5055}"

mkdir -p "$PKG_DIR" "$ADAPT_DIR" "$TOOLS_DIR" "$TASKS_DIR" "$LOG_DIR"
mkdir -p "$OPENWEBUI_DIR"
chown -R "$USER_NAME":"$USER_NAME" "$AIMusubi_HOME"

# ---------- Add Grafana APT repo (Ubuntu 24.04+ doesn’t ship grafana) ----------
echo "[*] Adding Grafana APT repository..."
mkdir -p /usr/share/keyrings
curl -fsSL https://apt.grafana.com/gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/grafana.gpg
echo "deb [signed-by=/usr/share/keyrings/grafana.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list

echo "[*] Updating apt and installing base packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  python3 python3-venv python3-dev python3-pip build-essential \
  git jq curl wget ca-certificates \
  dnsutils net-tools \
  nmap masscan fping snmp snmpd snmptrapd iproute2 traceroute \
  cron \
  prometheus grafana

# ---------- Ollama + Llama3 (local fallback LLM) ----------
echo "[*] Installing Ollama (local LLM backend)..."

if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.ai/install.sh | sh
else
  echo "[*] Ollama already installed — skipping."
fi

echo "[*] Pulling local Llama3 model (this may take a few minutes)..."
ollama pull llama3 || true

# ---------- Core Python venv + dependencies ----------
echo "[*] Creating Python venv for AIMusubi core..."
sudo -u "$USER_NAME" python3 -m venv "$VENV_DIR"
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"
pip install -U pip wheel

echo "[*] Installing core Python dependencies (FastAPI, LangGraph, gNMI, etc.)..."
pip install \
  fastapi "uvicorn[standard]" httpx pydantic prometheus_client python-multipart \
  langgraph langchain pygnmi grpcio-tools

# ---------- Generate FULL L5 api.py ----------
echo "[*] Generating AIMusubi L5 API at $PKG_DIR/api.py ..."
cat >"$PKG_DIR/api.py" <<'PY'
import os, re, json, time, sqlite3, pathlib, secrets, logging, subprocess, resource
from typing import Any, Dict, List, Optional

import httpx
from fastapi import FastAPI, HTTPException, Request, Body, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from prometheus_client import Counter, Gauge, Histogram, generate_latest, CONTENT_TYPE_LATEST
from pygnmi.client import gNMIclient  # minimal gNMI support (open-core)

BOOT_DIR = pathlib.Path(os.environ.get("AIMusubi_HOME", str(pathlib.Path.home() / "AIMusubi")))
DB_PATH  = BOOT_DIR / "state.db"
ADAPTER_DIR = pathlib.Path(os.environ.get("AIMusubi_ADAPTER_DIR", str(BOOT_DIR / "adapters")))
LEVEL    = int(os.getenv("AIMusubi_LEVEL","5"))
MEM_DAYS = int(os.getenv("AIMusubi_MEMORY_DAYS","360"))
RESTCONF_USER = os.getenv("RESTCONF_USER","NETOPS")
RESTCONF_PASS = os.getenv("RESTCONF_PASS","NETOPS")
RESTCONF_PORT = int(os.getenv("RESTCONF_PORT","443"))
RESTCONF_VERIFY_TLS = os.getenv("RESTCONF_VERIFY_TLS","false").lower() in ("1","true","yes")
AIMusubi_ALLOW_SHELL = os.getenv("AIMusubi_ALLOW_SHELL","1").lower() in ("1","true","yes")
GNMI_PORT = int(os.getenv("GNMI_PORT", "57400"))
GNMI_INSECURE = os.getenv("GNMI_INSECURE", "1").lower() in ("1","true","yes")
EAPI_PORT = int(os.getenv("EAPI_PORT", "443"))
EAPI_VERIFY_TLS = os.getenv("EAPI_VERIFY_TLS","false").lower() in ("1","true","yes")

# Vendor ID aliases so users/LLMs can say "cisco" instead of "cisco-iosxe"
VENDOR_ALIASES = {
    "cisco": "cisco-iosxe",
    "iosxe": "cisco-iosxe",

    "arista": "arista-eapi",
    "eos": "arista-eapi",
    "arista-eos": "arista-eapi",   # in case someone uses this name

    "vyos": "vyos"
}

def normalize_vendor(v: str) -> str:
    """Map common shorthand vendor IDs to the canonical adapter vendor key."""
    return VENDOR_ALIASES.get(v.lower(), v)

app = FastAPI(title="AIMusubi API — L5 Agnostic", version="full-2025.11.12")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

log = logging.getLogger("AIMusubi")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

# Prometheus
api_hits = Counter("AIMusubi_api_hits_total","hits",["path"])
req_hist = Histogram("AIMusubi_req_seconds","latency",["path"])
g_level  = Gauge("AIMusubi_level","agentic level")
g_last_err = Gauge("AIMusubi_last_error_ts","last error ts")


def _db()->sqlite3.Connection:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn=sqlite3.connect(DB_PATH, check_same_thread=False, timeout=5.0)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("""CREATE TABLE IF NOT EXISTS mem (ts INTEGER, kind TEXT, key TEXT, val TEXT)""")
    conn.execute("""CREATE TABLE IF NOT EXISTS creds (host TEXT PRIMARY KEY, username TEXT, password TEXT)""")
    conn.execute("""CREATE TABLE IF NOT EXISTS poll (id TEXT PRIMARY KEY, created_ts INTEGER, spec TEXT, enabled INTEGER)""")
    conn.execute("""CREATE TABLE IF NOT EXISTS adapters (vendor TEXT PRIMARY KEY, meta TEXT, updated_ts INTEGER)""")
    return conn

def _mem_put(kind:str,key:str,val:Any)->None:
    c=_db()
    c.execute("INSERT INTO mem(ts,kind,key,val) VALUES(?,?,?,?)",
              (int(time.time()),kind,key,json.dumps(val)))
    c.commit()
    c.close()

def get_host_creds(host:str):
    c=_db()
    r=c.execute("SELECT username,password FROM creds WHERE host=?",(host,)).fetchone()
    c.close()
    return (r[0],r[1]) if r and r[0] and r[1] else (RESTCONF_USER,RESTCONF_PASS)

# ---------- HTTP client helper ----------

def _http_client(timeout: float = 10.0, verify: bool = True):
    """
    Minimal HTTP client wrapper for RESTCONF, gNMI helpers, and general HTTP.

    - Uses HTTP_PROXY / HTTPS_PROXY / NO_PROXY from the environment (trust_env=True)
    """
    tr = httpx.HTTPTransport(retries=2, verify=verify)
    return httpx.Client(transport=tr, timeout=timeout, trust_env=True)

def _rc_base(host:str)->str:
    return f"https://{host}:{RESTCONF_PORT}"

# ---------- PROTOCOL HELPERS: RESTCONF ----------

def _protocol_restconf_get(host:str, path:str):
    with req_hist.labels("/restconf GET").time():
        base=_rc_base(host)
        auth=get_host_creds(host)
        hdr={"Accept":"application/yang-data+json","Content-Type":"application/yang-data+json"}
        with _http_client(verify=RESTCONF_VERIFY_TLS) as cl:
            r=cl.get(base+path, auth=auth, headers=hdr)
            r.raise_for_status()
            try:
                data=r.json()
            except Exception:
                data={"_raw":r.text[:20000]}
            proof={"proof_id":secrets.token_hex(8),
                   "ts":int(time.time()),
                   "tag":"restconf_get",
                   "host":host,"path":path}
            _mem_put("restconf","get",{"host":host,"status":r.status_code,"proof":proof})
            return {"data":data,"status":r.status_code,"proof":proof}

def _protocol_restconf_write(host:str, path:str, payload:Dict[str,Any], method:str):
    with req_hist.labels(f"/restconf {method}").time():
        base=_rc_base(host)
        auth=get_host_creds(host)
        hdr={"Accept":"application/yang-data+json","Content-Type":"application/yang-data+json"}
        with _http_client(verify=RESTCONF_VERIFY_TLS) as cl:
            m=method.upper()
            if m=="PATCH":
                r=cl.patch(base+path, json=payload or {}, headers=hdr, auth=auth)
            elif m=="PUT":
                r=cl.put(base+path, json=payload or {}, headers=hdr, auth=auth)
            elif m=="POST":
                r=cl.post(base+path, json=payload or {}, headers=hdr, auth=auth)
            elif m=="DELETE":
                r=cl.delete(base+path, headers=hdr, auth=auth)
            else:
                raise HTTPException(400,f"bad method {method}")
            proof={"proof_id":secrets.token_hex(8),
                   "ts":int(time.time()),
                   "tag":f"restconf_{m.lower()}",
                   "host":host,"path":path}
            _mem_put("restconf","write",{"host":host,"status":r.status_code,"proof":proof})
            out={"status":r.status_code,"proof":proof}
            if not (200<=r.status_code<300):
                out["error"]=(r.text or "")[:800]
            return out

# ---------- PROTOCOL HELPERS: Arista eAPI ----------

def _protocol_eapi_run(host:str, commands:List[str], fmt:str="json", version:int=1)->Dict[str,Any]:
    """Minimal Arista eAPI client using JSON-RPC over HTTPS."""
    auth = get_host_creds(host)
    url = f"https://{host}:{EAPI_PORT}/command-api"

    payload: Dict[str, Any] = {
        "jsonrpc": "2.0",
        "method": "runCmds",
        "params": {
            "version": version,
            "cmds": commands,
            "format": fmt,
        },
        "id": f"aimusubi-{int(time.time())}",
    }

    with req_hist.labels("/eapi runCmds").time():
        with _http_client(verify=EAPI_VERIFY_TLS) as cl:
            r = cl.post(url, json=payload, auth=auth)
            r.raise_for_status()
            jr = r.json()

    proof = {
        "proof_id": secrets.token_hex(8),
        "ts": int(time.time()),
        "tag": "eapi_runCmds",
        "host": host,
        "port": EAPI_PORT,
        "commands": commands,
    }
    _mem_put("eapi","runCmds",{
        "host": host,
        "commands": commands,
        "status": r.status_code,
        "proof": proof,
    })
    return {
        "status": "ok",
        "host": host,
        "commands": commands,
        "format": fmt,
        "result": jr,
        "proof": proof,
    }


# ---------- PROTOCOL HELPERS: gNMI ----------

def _protocol_gnmi_get(host:str, path:str):
    """Minimal open-core gNMI GET implementation.

    - Uses pygnmi.gNMIclient
    - Assumes OpenConfig-style path (e.g. "interfaces/interface[name=*]/state/admin-status")
    - Uses GNMI_PORT and GNMI_INSECURE from env
    - Reuses the same credential source as RESTCONF (get_host_creds)
    """
    with req_hist.labels("/gnmi GET").time():
        username, password = get_host_creds(host)
        try:
            # pygnmi expects target=(host, port)
            with gNMIclient(
                target=(host, GNMI_PORT),
                username=username,
                password=password,
                insecure=GNMI_INSECURE,
            ) as gc:
                # gNMI Get: path must be a list; we request JSON_IETF encoding
                result = gc.get(path=[path], encoding="JSON_IETF")

            proof = {
                "proof_id": secrets.token_hex(8),
                "ts": int(time.time()),
                "tag": "gnmi_get",
                "host": host,
                "path": path,
                "port": GNMI_PORT,
            }
            _mem_put(
                "gnmi",
                "get",
                {
                    "host": host,
                    "path": path,
                    "status": 200,
                    "proof": proof,
                },
            )
            return {
                "data": result,
                "status": 200,
                "proof": proof,
            }
        except Exception as e:
            g_last_err.set(int(time.time()))
            raise HTTPException(502, f"gNMI GET failed: {e}")

# ---------- PROTOCOL DISPATCHER ----------

def _protocol_exec(protocol:str, host:str, path:str,
                   payload:Optional[Dict[str,Any]], method:str):
    method = method.upper()
    if protocol == "restconf":
        if method == "GET":
            return _protocol_restconf_get(host, path)
        else:
            return _protocol_restconf_write(host, path, payload or {}, method)
    elif protocol == "gnmi":
        if method == "GET":
            return _protocol_gnmi_get(host, path)
        else:
            raise HTTPException(501, "gNMI SET/UPDATE not implemented.")
    elif protocol == "eapi":
        if method != "POST":
            raise HTTPException(400, "eAPI only supports POST")
        if not isinstance(payload, dict):
            raise HTTPException(400, "eAPI requires JSON payload with 'commands'")
        cmds = payload.get("commands")
        if not isinstance(cmds, list) or not cmds:
            raise HTTPException(400, "eAPI requires non-empty 'commands' list")
        fmt = payload.get("format","json")
        version = int(payload.get("version",1))
        return _protocol_eapi_run(host, cmds, fmt, version)
    else:
        raise HTTPException(400, f"Unsupported protocol: {protocol}")

# ---------- RESTCONF REQUEST WRAPPER ----------

class RCReq(BaseModel):
    host: str
    path: str
    method: str = "GET"
    payload: Optional[Dict[str, Any]] = None

    # NEW: allow approval flags in the JSON body (for LLM / tools)
    approve: Optional[bool] = False
    X_AIMusubi_Approve: Optional[str] = None


@app.post("/restconf/request")
def restconf_request(req: RCReq, request: Request):
    api_hits.labels("/restconf/request").inc()

    # 1. Work out whether this change is approved
    header_ok = request.headers.get("X-AIMusubi-Approve", "").lower() == "true"
    field_ok = bool(req.approve)  # allow {"approve": true} in JSON

    payload_ok = False
    raw_payload = req.payload or {}
    if isinstance(raw_payload, dict):
        val = raw_payload.get("X-AIMusubi-Approve")
        if isinstance(val, str):
            payload_ok = val.lower() == "true"
        elif isinstance(val, bool):
            payload_ok = val

    approved = header_ok or field_ok or payload_ok

    # 2. Block unsafe write operations that are not approved
    if req.method.upper() in {"PATCH", "PUT", "POST", "DELETE"} and not approved:
        _mem_put("restconf", "reject", {
            "host": req.host,
            "path": req.path,
            "reason": "missing approve"
        })
        raise HTTPException(403, "X-AIMusubi-Approve: true required")

    # 3. Strip any approval flag out of the payload before sending to device
    body = raw_payload
    if isinstance(body, dict):
        body = {k: v for k, v in body.items() if k not in ("X-AIMusubi-Approve", "approve", "verify")}

    # 4. Execute the RESTCONF call
    if req.method.upper() == "GET":
        jr = _protocol_restconf_get(req.host, req.path)
    else:
        jr = _protocol_restconf_write(req.host, req.path, body, req.method)

    # 5. Optional post-write verification still supported via payload.verify
    v = (raw_payload or {}).get("verify") if isinstance(raw_payload, dict) else None
    if v and isinstance(v, dict):
        ok = False
        vres: Dict[str, Any] = {}
        try:
            vres = _protocol_restconf_get(req.host, v["path"])
            ok = v.get("expect") is None or vres == v["expect"]
        except Exception as e:
            vres = {"error": str(e)}
        return {"status": jr, "verify": {"ok": ok, "result": vres}}

    return jr

# ---------- EAPI REQUEST WRAPPER ----------

class EAPIReq(BaseModel):
    host: str
    commands: List[str]
    format: str = "json"
    version: int = 1
    # Optional approval flags for environments that can't set headers
    approve: Optional[bool] = False
    X_AIMusubi_Approve: Optional[str] = None

@app.post("/eapi/request")
def eapi_request(req: EAPIReq, request: Request):
    api_hits.labels("/eapi/request").inc()

    # 1) Standard header-based approval (preferred)
    hdr = request.headers.get("X-AIMusubi-Approve", "").lower()

    # 2) Body-based approval (for LLM tools / Swagger that can't easily set headers)
    body_flag = (
        (req.X_AIMusubi_Approve is not None and str(req.X_AIMusubi_Approve).lower() == "true")
        or (str(req.approve).lower() == "true")
    )

    if not (hdr == "true" or body_flag):
        _mem_put(
            "eapi",
            "reject",
            {
                "host": req.host,
                "commands": req.commands,
                "reason": "missing approve",
            },
        )
        raise HTTPException(403, "X-AIMusubi-Approve: true required")

    return _protocol_eapi_run(
        host=req.host,
        commands=req.commands,
        fmt=req.format,
        version=req.version,
    )

# ---------- WEB FETCH (raw HTML saved) ----------

class WebFetchReq(BaseModel):
    url:str
    max_bytes:int=2_000_000
    timeout_sec:float=12.0

@app.post("/web/fetch")
def web_fetch(req: WebFetchReq):
    api_hits.labels("/web/fetch").inc()
    if not req.url.startswith("https://"):
        raise HTTPException(400,"https only")
    headers={"User-Agent":"AIMusubi/1.0 (+lab) Mozilla/5.0","Accept":"*/*"}
    with _http_client(timeout=req.timeout_sec, verify=True) as cl:
        r=cl.get(req.url, headers=headers)
        if r.status_code>=400:
            raise HTTPException(r.status_code, f"HTTP {r.status_code} at {r.url}")
        ctype=r.headers.get("content-type","").lower()
        body=r.content[:req.max_bytes]

        raw_text=body.decode("utf-8","ignore")

        text=None
        js=None
        if "application/json" in ctype:
            try:
                js=r.json()
            except Exception:
                text=raw_text
        else:
            raw=raw_text
            if "text/html" in ctype:
                raw=re.sub(r"(?is)<(script|style|noscript|nav|footer|header)[^>]*>.*?</\1>","",raw)
                raw=re.sub(r"(?s)<[^>]+>"," ",raw)
            text=re.sub(r"\s+"," ",raw).strip()

        return {
            "ok":True,
            "url":str(r.url),
            "content_type":ctype,
            "json":js,
            "text":text,
            "raw_content": raw_text[:50000]
        }

# ---------- ADAPTERS (manifest + auto-learn index) ----------

def _load_manifest(vendor:str)->Dict[str,Any]:
    mf=ADAPTER_DIR/ vendor / "manifest.json"
    if not mf.exists():
        raise HTTPException(404,f"adapter {vendor} not found")
    return json.loads(mf.read_text())

def _save_manifest(vendor:str, doc:Dict[str,Any])->None:
    (ADAPTER_DIR/vendor).mkdir(parents=True, exist_ok=True)
    (ADAPTER_DIR/vendor/"manifest.json").write_text(json.dumps(doc, indent=2))

def _paths_file(vendor:str)->pathlib.Path:
    return ADAPTER_DIR/vendor/"refs"/"paths.json"

class IntentReq(BaseModel):
    vendor:str
    intent:str
    params:Dict[str,Any]=Field(default_factory=dict)
    host:str
    method:str="GET"
    payload:Optional[Dict[str,Any]]=None

class AdapterIntentExecBody(BaseModel):
    host: str
    params: Dict[str, Any] = Field(default_factory=dict)
    method: str = "GET"
    payload: Optional[Dict[str, Any]] = None

@app.get("/adapters/{vendor}/intents")
def adapters_intents(vendor:str):
    vendor = normalize_vendor(vendor)
    man=_load_manifest(vendor)
    hints={}
    p=_paths_file(vendor)
    if p.exists():
        try:
            hints=json.loads(p.read_text()).get("intents",{})
        except Exception:
            hints={}
    return {
        "vendor":vendor,
        "base":man.get("base","/restconf/data"),
        "protocol":man.get("protocol","restconf"),
        "intents":man.get("intents",{}),
        "payloads":man.get("payloads",{}),
        "hints":hints
    }

def _resolve_paths(vendor:str, intent:str, params:Dict[str,Any])->List[str]:
    man=_load_manifest(vendor)
    base=(man.get("base") or "/restconf/data").rstrip("/")
    spec=man.get("intents",{}).get(intent)
    if spec is None:
        p=_paths_file(vendor)
        if p.exists():
            try:
                hints=json.loads(p.read_text()).get("intents",{})
                spec=hints.get(intent)
                if spec is None:
                    spec=hints.get("_yang_generated",{}).get(intent)
            except Exception:
                pass
        if spec is None:
            raise HTTPException(404,f"intent {intent} not found for {vendor}")

    specs = spec if isinstance(spec,list) else [spec]

    if man.get("protocol") == "gnmi":
        return [ s.format(**params) for s in specs ]
    else:
        return [ (base + "/" + s.format(**params)).rstrip("/") for s in specs ]

@app.post("/intent/exec")
def intent_exec(body: IntentReq):
    vendor = normalize_vendor(body.vendor)
    """
    Execute a high-level adapter intent.

    For protocol=restconf/gnmi:
      - Uses _resolve_paths() and _protocol_exec().

    For protocol=eapi:
      - Reads manifest int
      - Converts 'run:show ...' into commands list
      - Invokes _protocol_eapi_run() directly.
    """
    api_hits.labels("/intent/exec").inc()

    man = _load_manifest(vendor)
    protocol = man.get("protocol", "restconf")

    # --- Arista / eAPI path ---
    if protocol == "eapi":
        intents = man.get("intents", {})
        spec = intents.get(body.intent)
        if spec is None:
            raise HTTPException(
                status_code=404,
                detail=f"intent {body.intent} not found for {vendor}",
            )

        cmd = spec
        if isinstance(cmd, str) and cmd.startswith("run:"):
            cmd = cmd[len("run:"):].strip()

        fmt = "json"
        version = 1
        if isinstance(body.payload, dict):
            fmt = body.payload.get("format", fmt)
            try:
                version = int(body.payload.get("version", version))
            except Exception:
                pass

        resp = _protocol_eapi_run(
            host=body.host,
            commands=[cmd],
            fmt=fmt,
            version=version,
        )
        return {
            "ok": True,
            "vendor": vendor,
            "intent": body.intent,
            "protocol": protocol,
            "results": [resp],
        }

    # --- RESTCONF / gNMI path ---
    paths = _resolve_paths(vendor, body.intent, body.params or {})
    payloads = man.get("payloads", {})
    default_payload = (payloads.get(body.intent) or {}).get("default")

    pay = body.payload or default_payload or {}
    out = []
    for p in paths:
        out.append(_protocol_exec(protocol, body.host, p, pay, body.method))

    return {
        "ok": True,
        "vendor": vendor,
        "intent": body.intent,
        "protocol": protocol,
        "results": out,
    }

@app.post("/adapters/{vendor}/intents/{intent_name}")
def adapter_intent_exec(vendor: str, intent_name: str, body: AdapterIntentExecBody):
    vendor = normalize_vendor(vendor)
    """
    Convenience wrapper so tools (or the LLM) can call:
      POST /adapters/<vendor>/intents/<intent_name>
    instead of manually constructing /intent/exec payloads.
    """
    api_hits.labels("/adapters/intents/exec").inc()

    # Reuse the existing IntentReq model and intent_exec logic
    req = IntentReq(
        vendor=vendor,
        intent=intent_name,
        params=body.params,
        host=body.host,
        method=body.method,
        payload=body.payload,
    )
    return intent_exec(req)

# Learn/cache docs → extract basic RESTCONF paths
class DocCacheReq(BaseModel):
    url:str
    vendor:str

@app.post("/docs/cache")
def docs_cache(req: DocCacheReq):
    api_hits.labels("/docs/cache").inc()
    r=web_fetch(WebFetchReq(url=req.url))
    if not r.get("ok"):
        raise HTTPException(502,"fetch failed")

    raw_content=(r.get("raw_content") or "")[:500000]
    text_content=r.get("text") or ""

    vdir=ADAPTER_DIR/req.vendor/"refs"
    vdir.mkdir(parents=True, exist_ok=True)
    fn = re.sub(r"[^a-zA-Z0-9_.-]+","_", req.url)
    (vdir/f"{fn}.html").write_text(raw_content)

    intents: Dict[str, set] = {}
    for m in re.finditer(r"/restconf/data/[a-zA-Z0-9:_/\-={}%,.]+", text_content):
        s=m.group(0).strip().rstrip(").,;")
        if len(s)<200:
            intents.setdefault("discovered", set()).add(s)

    hints={
        "intents":{"_discovered": sorted(list(intents.get("discovered",[])))},
        "source": req.url,
        "updated_ts": int(time.time())
    }
    _paths_file(req.vendor).write_text(json.dumps(hints, indent=2))
    c=_db()
    c.execute(
        "INSERT INTO adapters(vendor,meta,updated_ts) VALUES(?,?,?) "
        "ON CONFLICT(vendor) DO UPDATE SET meta=?, updated_ts=?",
        (
            req.vendor,
            json.dumps({"last_url":req.url}),
            int(time.time()),
            json.dumps({"last_url":req.url}),
            int(time.time()),
        ),
    )
    c.commit()
    c.close()
    return {"ok":True, "hints":hints}

# YANG-based Discovery Endpoint (stub)
class YangCacheReq(BaseModel):
    vendor:str
    filename:str
    content:str

@app.post("/yang/parse-and-cache")
def yang_parse_and_cache(req: YangCacheReq):
    api_hits.labels("/yang/parse-and-cache").inc()

    yang_dir=ADAPTER_DIR/req.vendor/"yang"
    yang_dir.mkdir(parents=True, exist_ok=True)
    yang_file = yang_dir / req.filename
    yang_file.write_text(req.content)

    generated_paths = {
        "iface.status.gnmi": "interfaces/interface[name=*]/state/admin-status",
        "system.hostname.gnmi": "system/config/hostname"
    }

    hints={
        "intents":generated_paths,
        "source": req.filename,
        "updated_ts":int(time.time()),
        "generator":"stub"
    }

    p=_paths_file(req.vendor)
    existing_hints: Dict[str, Any] = {}
    if p.exists():
        existing_hints=json.loads(p.read_text())

    existing_hints["intents"] = existing_hints.get("intents",{})
    existing_hints["intents"].update(generated_paths)

    _paths_file(req.vendor).write_text(json.dumps(existing_hints, indent=2))

    return {"ok":True,"cached":str(yang_file),"hints":hints}

class ReindexReq(BaseModel):
    vendor:str

@app.post("/adapters/index")
def adapters_index(req: ReindexReq):
    api_hits.labels("/adapters/index").inc()
    vdir=ADAPTER_DIR/req.vendor/"refs"
    if not vdir.exists():
        raise HTTPException(404,"no refs dir")
    merged=set()
    for tf in vdir.glob("*.html"):
        try:
            t=tf.read_text()
            for m in re.finditer(r"/restconf/data/[a-zA-Z0-9:_/\-={}%,.]+", t):
                s=m.group(0).strip().rstrip(").,;")
                if len(s)<200:
                    merged.add(s)
        except Exception:
            pass

    hints={"intents":{"_discovered": sorted(list(merged))},
           "updated_ts":int(time.time())}
    _paths_file(req.vendor).write_text(json.dumps(hints, indent=2))
    return {"ok":True,"hints":hints}

# ---------- Discovery ----------

class PingReq(BaseModel):
    targets:List[str]
    count:int=1
    timeout_ms:int=400

@app.post("/discover/ping")
def discover_ping(req: PingReq):
    api_hits.labels("/discover/ping").inc()
    out=[]
    for t in req.targets:
        try:
            r=subprocess.run(
                ["fping","-c",str(req.count),"-t",str(req.timeout_ms),t],
                capture_output=True,text=True,timeout=10
            )
            out.append({"target":t,"code":r.returncode,
                        "stdout":r.stdout,"stderr":r.stderr})
        except Exception as e:
            out.append({"target":t,"error":str(e)})
    return {"ok":True,"results":out}

class ScanReq(BaseModel):
    target:str
    top_ports:int=100

@app.post("/discover/scan")
def discover_scan(req: ScanReq):
    api_hits.labels("/discover/scan").inc()
    try:
        r=subprocess.run(
            ["nmap","--top-ports",str(req.top_ports),"-Pn","-n","-T4",req.target],
            capture_output=True,text=True,timeout=120
        )
        return {"ok":True,"stdout":r.stdout,"stderr":r.stderr,"code":r.returncode}
    except Exception as e:
        return {"ok":False,"error":str(e)}

# ---------- Polling + Cron ----------

class PollStartReq(BaseModel):
    targets:List[str]
    interval_sec:int=30
    intents:List[str]=Field(default_factory=list)
    vendor:str="cisco-iosxe"

class PollTickReq(BaseModel):
    limit:Optional[int]=None

@app.post("/poll/start")
def poll_start(req: PollStartReq):
    api_hits.labels("/poll/start").inc()
    pid=secrets.token_hex(8)
    spec={"targets":req.targets,"interval_sec":req.interval_sec,
          "intents":req.intents,"vendor":req.vendor}
    c=_db()
    c.execute("INSERT INTO poll(id,created_ts,spec,enabled) VALUES(?,?,?,1)",
              (pid,int(time.time()),json.dumps(spec)))
    c.commit()
    c.close()
    return {"ok":True,"id":pid,"spec":spec}

@app.post("/poll/stop")
def poll_stop(id:str):
    api_hits.labels("/poll/stop").inc()
    c=_db()
    c.execute("UPDATE poll SET enabled=0 WHERE id=?",(id,))
    c.commit()
    c.close()
    return {"ok":True,"id":id}

@app.get("/poll/list")
def poll_list():
    api_hits.labels("/poll/list").inc()
    c=_db()
    rows=c.execute("SELECT id,spec,enabled FROM poll").fetchall()
    c.close()
    return {
        "ok":True,
        "polls":[
            {"id":r[0],"spec":json.loads(r[1]),"enabled":bool(r[2])}
            for r in rows
        ]
    }

@app.post("/poll/tick")
def poll_tick(req: PollTickReq = Body(default=None)):
    api_hits.labels("/poll/tick").inc()
    c=_db()
    rows=c.execute("SELECT id,spec FROM poll WHERE enabled=1").fetchall()
    c.close()
    count=0
    results=[]
    for pid, spec_json in rows:
        if req and req.limit and count >= req.limit:
            break
        spec=json.loads(spec_json)
        vendor = normalize_vendor(spec.get("vendor","cisco-iosxe"))
        intents = spec.get("intents") or []
        targets = spec.get("targets") or []

        try:
            man=_load_manifest(vendor)
        except HTTPException:
            log.warning(f"Poll {pid} vendor {vendor} manifest not found, skipping.")
            continue

        t0=time.time()
        per_poll=[]
        for host in targets:
            for intent in intents:
                try:
                    r=intent_exec(
                        IntentReq(
                            vendor=vendor,intent=intent,
                            params={},host=host,
                            method="GET",payload=None
                        )
                    )
                    ok=True
                except Exception as e:
                    r={"ok":False,"error":str(e)}
                    ok=False
                    g_last_err.set(int(time.time()))
                per_poll.append({"host":host,"intent":intent,"ok":ok,"r":r})
        dt=time.time()-t0
        _mem_put("poll","tick",{"id":pid,"dt_sec":round(dt,3),"count":len(per_poll)})
        results.append({"id":pid,"dt_sec":round(dt,3),"results":per_poll})
        count+=1
    return {"ok":True,"executed":count,"polls":results}

class CronSetReq(BaseModel):
    interval_min:int=1

@app.post("/scheduler/cron/set")
def cron_set(req: CronSetReq):
    api_hits.labels("/scheduler/cron/set").inc()
    if not (1<=req.interval_min<=59):
        raise HTTPException(400,"interval 1-59 min")

    cmd = f'curl -s -X POST http://127.0.0.1:{os.getenv("API_PORT","5055")}/poll/tick'
    try:
        current_crontab=subprocess.run(
            ["crontab","-l"],
            capture_output=True,text=True,check=False,timeout=5
        ).stdout or ""
    except subprocess.TimeoutExpired:
        current_crontab=""

    new_crontab = [
        line for line in current_crontab.splitlines()
        if "# AIMusubi-POLL-L5" not in line and line.strip()
    ]
    cron_entry=f"*/{req.interval_min} * * * * {cmd} # AIMusubi-POLL-L5"
    new_crontab.append(cron_entry)

    subprocess.run(
        ["crontab","-"],
        input="\n".join(new_crontab) + "\n",
        capture_output=True,text=True,check=True
    )

    return {"ok":True,"crontab":new_crontab,"message":"cron entry set or updated"}

@app.post("/scheduler/cron/remove")
def cron_remove():
    api_hits.labels("/scheduler/cron/remove").inc()
    try:
        current_crontab=subprocess.run(
            ["crontab","-l"],
            capture_output=True,text=True,check=False,timeout=5
        ).stdout or ""
    except subprocess.TimeoutExpired:
        current_crontab=""
    new_crontab = [
        line for line in current_crontab.splitlines()
        if "# AIMusubi-POLL-L5" not in line and line.strip()
    ]
    subprocess.run(
        ["crontab","-"],
        input="\n".join(new_crontab) + "\n",
        capture_output=True,text=True,check=True
    )
    return {"ok":True,"message":"cron entry removed"}

# ---------- Safe Shell Runner + Tasks ----------

class ShellReq(BaseModel):
    cmd:str
    args:List[str]=Field(default_factory=list)

@app.post("/shell/exec")
def shell_exec(req:ShellReq, request:Request):
    api_hits.labels("/shell/exec").inc()
    if not AIMusubi_ALLOW_SHELL:
        raise HTTPException(403,"shell disabled")
    if request.headers.get("X-AIMusubi-Approve","").lower()!="true":
        raise HTTPException(403,"X-AIMusubi-Approve: true required")
    if req.cmd not in ["fping","nmap","curl","crontab"]:
        raise HTTPException(400,f"command {req.cmd} not allowed")

    resource.setrlimit(resource.RLIMIT_CPU, (1, 2))
    resource.setrlimit(resource.RLIMIT_AS, (100 * 1024 * 1024, 100 * 1024 * 1024))

    env = {k: v for k, v in os.environ.items() if not k.startswith("http_proxy")}

    try:
        proc=subprocess.run(
            [req.cmd] + req.args,
            capture_output=True,text=True,check=True,timeout=10,env=env
        )
        return {"ok":True,"stdout":proc.stdout,"stderr":proc.stderr}
    except subprocess.CalledProcessError as e:
        return {"ok":False,"error":e.stderr,"stdout":e.stdout,"code":e.returncode}
    except Exception as e:
        return {"ok":False,"error":str(e),"code":99}

class TasksReq(BaseModel):
    name:str
    args:List[str]=Field(default_factory=list)

@app.post("/tasks/exec")
def tasks_exec(req:TasksReq, request:Request):
    api_hits.labels("/tasks/exec").inc()
    if request.headers.get("X-AIMusubi-Approve","").lower()!="true":
        raise HTTPException(403,"X-AIMusubi-Approve: true required")

    tasks_dir = pathlib.Path(os.getenv("TASKS_DIR", str(BOOT_DIR / "tasks")))
    task_path=tasks_dir / f"{req.name}.sh"
    if not task_path.exists() or not os.access(task_path, os.X_OK):
        raise HTTPException(404,f"task {req.name} not found or not executable")

    resource.setrlimit(resource.RLIMIT_CPU, (5, 10))
    resource.setrlimit(resource.RLIMIT_AS, (500 * 1024 * 1024, 500 * 1024 * 1024))

    env = {k: v for k, v in os.environ.items() if not k.startswith("http_proxy")}

    try:
        proc=subprocess.run(
            [str(task_path)] + req.args,
            capture_output=True,text=True,check=True,timeout=30,env=env
        )
        return {"ok":True,"stdout":proc.stdout,"stderr":proc.stderr}
    except subprocess.CalledProcessError as e:
        return {"ok":False,"error":e.stderr,"stdout":e.stdout,"code":e.returncode}
    except Exception as e:
        return {"ok":False,"error":str(e),"code":99}

# ---------- Creds / Health / Metrics ----------

class CredsReq(BaseModel):
    host:str
    username:str
    password:str

@app.post("/creds/set")
def set_creds(req:CredsReq):
    api_hits.labels("/creds/set").inc()
    c=_db()
    c.execute(
        "INSERT INTO creds(host,username,password) VALUES(?,?,?) "
        "ON CONFLICT(host) DO UPDATE SET username=?, password=?",
        (req.host, req.username, req.password, req.username, req.password),
    )
    c.commit()
    c.close()
    return {"ok":True,"host":req.host,"message":"credentials saved"}

@app.get("/health")
def health():
    api_hits.labels("/health").inc()
    g_level.set(LEVEL)
    try:
        c=_db()
        total_mem=c.execute("SELECT COUNT(*) FROM mem").fetchone()[0]
        c.close()
    except Exception:
        total_mem="N/A"
    return {
        "ok":True,
        "status":"up",
        "level":LEVEL,
        "memory_retained_days":MEM_DAYS,
        "total_mem_entries":total_mem,
        "tls_verify":RESTCONF_VERIFY_TLS,
        "shell_enabled":AIMusubi_ALLOW_SHELL,
    }

@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.get("/")
def ui_root():
    return {
        "Welcome":"AIMusubi L5 Agnostic Lab API",
        "docs":"/docs",
        "health":"/health",
        "metrics":"/metrics"
    }

PY

chown -R "$USER_NAME":"$USER_NAME" "$CORE_DIR"

# ---------- Seed adapter manifests ----------
echo "[*] Seeding adapter manifests..."
mkdir -p "$ADAPT_DIR"/{cisco-iosxe,arista-eapi,arista-eos,vyos}/{refs,yang}

cat >"$ADAPT_DIR/cisco-iosxe/manifest.json"<<'J'
{
  "vendor": "cisco-iosxe",
  "protocol": "restconf",
  "base": "/restconf/data",
  "capabilities": ["restconf", "yang", "ietf", "native"],
  "research": {
    "preferred": [
      "https://www.rfc-editor.org/rfc/rfc8349",
      "https://developer.cisco.com/site/ios-xe/"
    ]
  },
  "intents": {
    "iface.list": "ietf-interfaces:interfaces",
    "iface.ipv4": "ietf-interfaces:interfaces/interface={name}/ietf-ip:ipv4",

    "iface.admin-down": "ietf-interfaces:interfaces/interface={name}/ietf-interfaces:enabled",
    "iface.admin-up":   "ietf-interfaces:interfaces/interface={name}/ietf-interfaces:enabled",

    "routing.v4.rib": "ietf-routing:routing-state/routing-instance=default/ribs/rib=ipv4-default",

    "cpu.util":  "Cisco-IOS-XE-process-cpu-oper:cpu-usage/cpu-utilization",
    "mem.stats": "Cisco-IOS-XE-memory-oper:memory-statistics/memory-statistic",

    "ospf.events": "Cisco-IOS-XE-ospf-oper:ospf-oper-data",

    "ospf.neigh": "Cisco-IOS-XE-ospf-oper:ospf-oper-data",
    "ospf.db":    "Cisco-IOS-XE-ospf-oper:ospf-oper-data",
    "ospf.if":    "Cisco-IOS-XE-ospf-oper:ospf-oper-data",

    "sw.version": "Cisco-IOS-XE-platform-oper:platform-oper-data",

    "cdp.neigh":  "Cisco-IOS-XE-cdp-oper:cdp-neighbor-details",
    "lldp.neigh": "Cisco-IOS-XE-lldp-oper:lldp-entries",

    "logs.events": "Cisco-IOS-XE-logging-oper:logging"
  },
  "payloads": {
    "iface.admin-down": {
      "default": { "ietf-interfaces:enabled": false }
    },
    "iface.admin-up": {
      "default": { "ietf-interfaces:enabled": true }
    }
  },
  "hints": {
    "iface.list": {
      "kind": "oper",
      "summary": "List all interfaces with admin/oper state and addressing."
    },
    "iface.ipv4": {
      "kind": "oper",
      "needs": ["name"],
      "summary": "IPv4 config for a single interface via ietf-ip."
    },
    "iface.admin-down": {
      "kind": "config",
      "danger": "Disables the interface. Always confirm impact first."
    },
    "iface.admin-up": {
      "kind": "config",
      "danger": "Enables the interface. Make sure IP and routing are valid."
    },
    "cpu.util": {
      "kind": "oper",
      "summary": "CPU utilization snapshot from IOS-XE process CPU model."
    },
    "mem.stats": {
      "kind": "oper",
      "summary": "Memory statistics for the device."
    },
    "ospf.events": {
      "kind": "oper",
      "summary": "Full OSPF operational state (instances, areas, interfaces, neighbors, LSAs)."
    },
    "ospf.neigh": {
      "kind": "oper",
      "summary": "Focused OSPF neighbor view per interface/area."
    },
    "ospf.db": {
      "kind": "oper",
      "summary": "OSPF database / LSDB view from ospf-oper-data."
    },
    "ospf.if": {
      "kind": "oper",
      "summary": "OSPF interface-level state (DR/BDR, state, neighbors)."
    },
    "sw.version": {
      "kind": "oper",
      "summary": "Platform / software version summary."
    },
    "cdp.neigh": {
      "kind": "oper",
      "summary": "CDP neighbor details."
    },
    "lldp.neigh": {
      "kind": "oper",
      "summary": "LLDP neighbor entries."
    },
    "logs.events": {
      "kind": "oper",
      "summary": "System logging events."
    }
  }
}
J

cat >"$ADAPT_DIR/arista-eapi/manifest.json"<<'J'
{
  "vendor": "arista-eapi",
  "protocol": "eapi",
  "base": "eapi://",
  "capabilities": ["eapi", "cli"],
  "research": {
    "preferred": [
      "https://www.arista.com/en/um-eos/eos-open-shortest-path-first-version-2",
      "https://github.com/arista-eosplus/pyeapi"
    ]
  },
  "intents": {
    "iface.list":  "run:show interfaces status",
    "iface.ipv4":  "run:show ip interface brief",

    "iface.admin-down": "run:configure terminal || interface {name} || shutdown",
    "iface.admin-up":   "run:configure terminal || interface {name} || no shutdown",

    "routing.v4.rib": "run:show ip route",

    "cpu.util":  "run:show processes top once",
    "mem.stats": "run:show memory",

    "ospf.events": "run:show ip ospf neighbor",

    "ospf.neigh": "run:show ip ospf neighbor",
    "ospf.db":    "run:show ip ospf database",
    "ospf.if":    "run:show ip ospf interface",

    "sw.version": "run:show version",

    "cdp.neigh":  "run:show cdp neighbors",
    "lldp.neigh": "run:show lldp neighbors",

    "logs.events": "run:show logging"
  },
  "payloads": {},
  "hints": {
    "iface.admin-down": {
      "kind": "config",
      "danger": "Shuts the interface on EOS; traffic stops."
    },
    "iface.admin-up": {
      "kind": "config",
      "danger": "No shutdown; confirm link/route impact."
    },
    "cpu.util": {
      "kind": "oper",
      "summary": "Top-like CPU snapshot."
    },
    "mem.stats": {
      "kind": "oper",
      "summary": "High-level memory stats."
    },
    "ospf.neigh": {
      "kind": "oper",
      "summary": "OSPFv2 neighbor table (show ip ospf neighbor)."
    },
    "ospf.db": {
      "kind": "oper",
      "summary": "OSPFv2 database / LSAs (show ip ospf database)."
    },
    "ospf.if": {
      "kind": "oper",
      "summary": "OSPFv2 per-interface state (show ip ospf interface)."
    },
    "logs.events": {
      "kind": "oper",
      "summary": "Recent logging output; may be large."
    }
  }
}
J

cat >"$ADAPT_DIR/arista-eos/manifest.json"<<'J'
{
  "vendor": "arista-eapi",
  "protocol": "eapi",
  "base": "eapi://",
  "capabilities": ["eapi", "cli"],
  "research": {
    "preferred": [
      "https://www.arista.com/en/um-eos/eos-open-shortest-path-first-version-2",
      "https://github.com/arista-eosplus/pyeapi"
    ]
  },
  "intents": {
    "iface.list":  "run:show interfaces status",
    "iface.ipv4":  "run:show ip interface brief",

    "iface.admin-down": "run:configure terminal || interface {name} || shutdown",
    "iface.admin-up":   "run:configure terminal || interface {name} || no shutdown",

    "routing.v4.rib": "run:show ip route",

    "cpu.util":  "run:show processes top once",
    "mem.stats": "run:show memory",

    "ospf.events": "run:show ip ospf neighbor",

    "ospf.neigh": "run:show ip ospf neighbor",
    "ospf.db":    "run:show ip ospf database",
    "ospf.if":    "run:show ip ospf interface",

    "sw.version": "run:show version",

    "cdp.neigh":  "run:show cdp neighbors",
    "lldp.neigh": "run:show lldp neighbors",

    "logs.events": "run:show logging"
  },
  "payloads": {},
  "hints": {
    "iface.admin-down": {
      "kind": "config",
      "danger": "Shuts the interface on EOS; traffic stops."
    },
    "iface.admin-up": {
      "kind": "config",
      "danger": "No shutdown; confirm link/route impact."
    },
    "cpu.util": {
      "kind": "oper",
      "summary": "Top-like CPU snapshot."
    },
    "mem.stats": {
      "kind": "oper",
      "summary": "High-level memory stats."
    },
    "ospf.neigh": {
      "kind": "oper",
      "summary": "OSPFv2 neighbor table (show ip ospf neighbor)."
    },
    "ospf.db": {
      "kind": "oper",
      "summary": "OSPFv2 database / LSAs (show ip ospf database)."
    },
    "ospf.if": {
      "kind": "oper",
      "summary": "OSPFv2 per-interface state (show ip ospf interface)."
    },
    "logs.events": {
      "kind": "oper",
      "summary": "Recent logging output; may be large."
    }
  }
}
J

# --- VyOS adapter manifest (RESTCONF/YANG) ---
cat >"$ADAPT_DIR/vyos/manifest.json"<<'EOF'
{
  "vendor": "vyos",
  "protocol": "restconf",
  "base": "/restconf/data",
  "capabilities": ["restconf", "yang"],
  "research": {
    "preferred": [
      "https://docs.vyos.io/en/latest/automation/restconf.html",
      "https://docs.vyos.io/",
      "https://docs.frrouting.org/en/latest/"
    ]
  },
  "intents": {
    "iface.list": "vyos-interfaces:interfaces",
    "system.version": "vyos-system:system/image",
    "routing.state": "ietf-routing:routing-state",
    "routing.v4.rib": "ietf-routing:routing-state/routing-instance=default/ribs/rib=ipv4/routes",
    "ospf.state": "frr-ospfd:ospf/state",
    "ospf.neigh": "frr-ospfd:ospf/state/neighbors",
    "ospf.db": "frr-ospfd:ospf/state/lsdb",
    "ospf.if": "frr-ospfd:ospf/state/interfaces"
  },
  "payloads": {},
  "hints": {
    "auth": {
      "method": "header",
      "header": "X-Auth-Token",
      "note": "Use the API key (e.g. 'vyos-api-key') as the X-Auth-Token when talking to VyOS via RESTCONF."
    },
    "iface.list": { "kind": "oper", "summary": "List all VyOS interfaces and IP addressing from vyos-interfaces YANG model." },
    "system.version": { "kind": "oper", "summary": "System image version, install time, and bootloader info." },
    "routing.state": { "kind": "oper", "summary": "Full routing-state tree (all instances, RIBs, IPv4/IPv6 tables)." },
    "routing.v4.rib": { "kind": "oper", "summary": "IPv4 route table from the default routing-instance." },
    "ospf.state": { "kind": "oper", "summary": "Global OSPFv2 state, including router-id, areas, interfaces, and neighbors." },
    "ospf.neigh": { "kind": "oper", "summary": "OSPF neighbors (similar to 'show ip ospf neighbor')." },
    "ospf.db": { "kind": "oper", "summary": "OSPF LSDB (similar to 'show ip ospf database')." },
    "ospf.if": { "kind": "oper", "summary": "OSPF interface state (similar to 'show ip ospf interface')." }
  }
}

EOF

chown -R "$USER_NAME":"$USER_NAME" "$ADAPT_DIR"

# ---------- /etc/AIMusubi env ----------
echo "[*] Writing /etc/AIMusubi/AIMusubi.env..."
mkdir -p /etc/AIMusubi
tee /etc/AIMusubi/AIMusubi.env >/dev/null <<ENV
# AIMusubi core
AIMusubi_HOME=$AIMusubi_HOME
AIMusubi_ADAPTER_DIR=$ADAPT_DIR
AIMusubi_LEVEL=5
AIMusubi_MEMORY_DAYS=360
AIMusubi_ALLOW_SHELL=1

# RESTCONF defaults (lab-friendly)
RESTCONF_USER=NETOPS
RESTCONF_PASS=NETOPS
RESTCONF_PORT=443
RESTCONF_VERIFY_TLS=false

# gNMI defaults
GNMI_PORT=57400
GNMI_INSECURE=1

# EAPI (Arista)
EAPI_PORT=443
EAPI_VERIFY_TLS=false

# Optional proxy / research
#HTTP_PROXY=http://proxy.example.com:3128
#HTTPS_PROXY=http://proxy.example.com:3128
#NO_PROXY=localhost,127.0.0.1

# Optional Gemini / other keys
#GOOGLE_API_KEY=your_key_here
ENV

# ---------- AIMusubi API service ----------
echo "[*] Creating systemd service for AIMusubi-api..."
tee /etc/systemd/system/AIMusubi-api.service >/dev/null <<EOF
[Unit]
Description=AIMusubi L5 Agnostic API (Full Stack)
After=network-online.target
Wants=network-online.target

[Service]
User=$USER_NAME
WorkingDirectory=$CORE_DIR
EnvironmentFile=/etc/AIMusubi/AIMusubi.env
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONPATH=$AIMusubi_HOME
Environment=VIRTUAL_ENV=$VENV_DIR
Environment=CORE_DIR=$CORE_DIR
Environment=TASKS_DIR=$TASKS_DIR
Environment=API_PORT=$API_PORT
ExecStart=$VENV_DIR/bin/uvicorn AIMusubi.api:app --host 0.0.0.0 --port $API_PORT
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# ---------- OPA ----------
echo "[*] Installing OPA..."
OPAV="0.68.0"
curl -fsSL -o /usr/local/bin/opa "https://openpolicyagent.org/downloads/v${OPAV}/opa_linux_amd64_static"
chmod +x /usr/local/bin/opa

mkdir -p /etc/opa
tee /etc/systemd/system/opa.service >/dev/null <<EOF
[Unit]
Description=Open Policy Agent (OPA)
After=network-online.target
Wants=network-online.target

[Service]
User=$USER_NAME
ExecStart=/usr/local/bin/opa run --server --addr=0.0.0.0:8181 /etc/opa
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# ---------- SNMP trap intake + handler ----------
echo "[*] Configuring snmptrapd and SNMP trap handler..."

# Backup existing snmptrapd config if present
if [ -f /etc/snmp/snmptrapd.conf ]; then
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  echo "  - Found existing snmptrapd config, backing it up to /etc/snmp/snmptrapd.conf.bak-$TIMESTAMP"
  mv /etc/snmp/snmptrapd.conf "/etc/snmp/snmptrapd.conf.bak-$TIMESTAMP"
fi

# Write new snmptrapd configuration
tee /etc/snmp/snmptrapd.conf >/dev/null <<SNC
authCommunity execute public
disableAuthorization yes
traphandle default /bin/sh $TOOLS_DIR/snmp-trap-handler.sh
SNC

# Trap handler script
cat >"$TOOLS_DIR/snmp-trap-handler.sh"<<'EOF'
#!/usr/bin/env bash
LOG_FILE="$LOG_DIR/snmptraps.log"
DATE=$(date -Is)
read -r HOSTNAME
read -r IP_ADDR
read -r OID
echo "$DATE | HOST=$HOSTNAME | IP=$IP_ADDR | OID=$OID | PAYLOAD:" >> "$LOG_FILE"
while IFS= read -r LINE; do
  echo "  $LINE" >> "$LOG_FILE"
done
EOF
chmod +x "$TOOLS_DIR/snmp-trap-handler.sh"

# ---------- Example task + tools helpers (start/stop/backup/restore) ----------
echo "[*] Generating example task + AIMusubi tools (startup/shutdown/backup/restore)..."

# Example task
cat >"$TASKS_DIR/hello_world.sh"<<'EOF'
#!/usr/bin/env bash
echo "Running task 'hello_world'..."
echo "Environment: AIMusubi_HOME=${AIMusubi_HOME:-$HOME/AIMusubi}"
echo "Arguments: Host=$1, Interface=$2"
echo "Task finished successfully."
EOF
chmod +x "$TASKS_DIR/hello_world.sh"

# Startup helper
cat >"$TOOLS_DIR/aimusubi-startup.sh"<<'EOF'
#!/usr/bin/env bash
# ────────────────────────────────────────────────
# AIMusubi – System Startup Helper
# ────────────────────────────────────────────────
set -euo pipefail

API_PORT="${API_PORT:-5055}"

step() {
  local msg="$1"
  printf ">>> %-60s" "$msg"
}

ok() {
  echo " ✓"
}

warn() {
  echo " ⚠"
}

echo "======================================================="
echo "  AIMusubi – System Startup"
echo "======================================================="

SERVICES=(
  "AIMusubi-api"
  "prometheus"
  "grafana-server"
  "open-webui"
  "opa"
  "snmptrapd"
  "cron"
)

for svc in "${SERVICES[@]}"; do
  step "Starting service: $svc"
  if systemctl is-active --quiet "$svc"; then
    echo " already running"
  else
    if sudo systemctl start "$svc"; then
      ok
    else
      warn
      echo "    -> Failed to start $svc (check: sudo journalctl -u $svc -n 50 --no-pager)"
    fi
  fi
done

step "Checking AIMusubi API health on port $API_PORT"
sleep 3
if curl -s "http://127.0.0.1:${API_PORT}/health" | grep -q '"ok": true'; then
  ok
else
  warn
  echo "    -> API did not return ok:true"
  echo "       Check logs with:"
  echo "         sudo journalctl -u AIMusubi-api.service -n 50 --no-pager"
fi

echo
echo "AIMusubi startup complete."
echo "API:       http://127.0.0.1:${API_PORT}/health"
echo "Grafana:   http://127.0.0.1:3000"
echo "Prometheus:http://127.0.0.1:9090"
echo "Open WebUI:http://127.0.0.1:8081"
echo "======================================================="
EOF
chmod +x "$TOOLS_DIR/aimusubi-startup.sh"

# Shutdown helper
cat >"$TOOLS_DIR/aimusubi-shutdown.sh"<<'EOF'
#!/usr/bin/env bash
# ────────────────────────────────────────────────
# AIMusubi – System Shutdown Helper
# ────────────────────────────────────────────────
set -euo pipefail

step() {
  local msg="$1"
  printf ">>> %-60s" "$msg"
}

ok() {
  echo " ✓"
}

info() {
  echo
  echo "    $*"
}

echo "======================================================="
echo "  AIMusubi – System Shutdown"
echo "======================================================="

SERVICES=(
  "open-webui"
  "grafana-server"
  "prometheus"
  "AIMusubi-api"
  "opa"
  "snmptrapd"
  "cron"
)

for svc in "${SERVICES[@]}"; do
  step "Stopping service: $svc"
  if systemctl is-active --quiet "$svc"; then
    if sudo systemctl stop "$svc"; then
      ok
    else
      echo " ⚠"
      info "Failed to stop $svc (check: sudo journalctl -u $svc -n 50 --no-pager)"
    fi
  else
    echo " (not running)"
  fi
done

step "Flushing filesystem buffers (sync)"
sync || true
ok

echo
echo "All AIMusubi-related services requested to stop."
echo "Safe to snapshot or power off once disk activity is idle."
echo "======================================================="
EOF
chmod +x "$TOOLS_DIR/aimusubi-shutdown.sh"

# Backup helper
cat >"$TOOLS_DIR/aimusubi-backup.sh"<<'EOF'
#!/usr/bin/env bash
# ────────────────────────────────────────────────
# AIMusubi – Tarball Backup Helper
# ────────────────────────────────────────────────
set -euo pipefail

AIMUSUBI_HOME="${AIMusubi_HOME:-$HOME/AIMusubi}"

DATE_TIME="$(date +%Y%m%d_%H%M%S)"
HOSTNAME_SHORT="$(hostname -s || echo host)"
OUT="${AIMUSUBI_HOME}/AIMusubi_backup_${HOSTNAME_SHORT}_${DATE_TIME}.tar.gz"

echo "======================================================="
echo "  AIMusubi – Backup"
echo "======================================================="
echo "AIMusubi home: ${AIMUSUBI_HOME}"
echo "Output file:   ${OUT}"
echo

echo ">>> Hint: For a clean snapshot run: aimusubi-shutdown.sh first."
echo

tar -czf "${OUT}" \
  "${AIMUSUBI_HOME}/core" \
  "${AIMUSUBI_HOME}/adapters" \
  "${AIMUSUBI_HOME}/tools" \
  "${AIMUSUBI_HOME}/tasks" \
  "${AIMUSUBI_HOME}/logs" \
  "${AIMUSUBI_HOME}/state.db" \
  /etc/AIMusubi \
  /etc/systemd/system/AIMusubi-api.service 2>/dev/null || true

echo
echo "Backup complete."
echo "Tarball created at:"
echo "  ${OUT}"
echo "======================================================="
EOF
chmod +x "$TOOLS_DIR/aimusubi-backup.sh"

# Restore helper
cat >"$TOOLS_DIR/aimusubi-restore.sh"<<'EOF'
#!/usr/bin/env bash
# ────────────────────────────────────────────────
# AIMusubi – Tarball Restore Helper
# ────────────────────────────────────────────────
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "This restore script must be run as root (sudo)."
  exit 1
fi

ARCHIVE="${1:-}"

if [[ -z "${ARCHIVE}" ]]; then
  echo "Usage: sudo ./aimusubi-restore.sh /path/to/AIMusubi_backup_*.tar.gz"
  exit 1
fi

if [[ ! -f "${ARCHIVE}" ]]; then
  echo "Error: Archive not found: ${ARCHIVE}"
  exit 1
fi

echo "======================================================="
echo "  AIMusubi – Restore"
echo "======================================================="
echo "Archive: ${ARCHIVE}"
echo
echo "This will overwrite:"
echo "  - /home/<user>/AIMusubi/core"
echo "  - /home/<user>/AIMusubi/adapters"
echo "  - /home/<user>/AIMusubi/tools"
echo "  - /home/<user>/AIMusubi/tasks"
echo "  - /home/<user>/AIMusubi/logs"
echo "  - /home/<user>/AIMusubi/state.db"
echo "  - /etc/AIMusubi"
echo "  - /etc/systemd/system/AIMusubi-api.service"
echo
read -rp "Proceed with restore? [y/N]: " CONFIRM
CONFIRM="${CONFIRM,,}"

if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "yes" ]]; then
  echo "Restore cancelled."
  exit 0
fi

echo
echo ">>> Extracting backup tarball to filesystem root (/)..."
tar -xzf "${ARCHIVE}" -C /

echo
echo ">>> Reloading systemd daemon..."
systemctl daemon-reload

echo
echo "Restore complete."
echo "You may want to run:"
echo "  systemctl restart AIMusubi-api"
echo "  systemctl restart prometheus grafana-server open-webui opa snmptrapd cron"
echo "======================================================="
EOF
chmod +x "$TOOLS_DIR/aimusubi-restore.sh"


# ---------- Prometheus config ----------
echo "[*] Configuring Prometheus to scrape AIMusubi..."

# Backup existing Prometheus config if present
if [ -f /etc/prometheus/prometheus.yml ]; then
  TIMESTAMP=$(date +%Y%m%d-%H%M%S)
  echo "  - Found existing Prometheus config, backing up to /etc/prometheus/prometheus.yml.bak-$TIMESTAMP"
  mv /etc/prometheus/prometheus.yml "/etc/prometheus/prometheus.yml.bak-$TIMESTAMP"
fi

# Write new Prometheus configuration
tee /etc/prometheus/prometheus.yml >/dev/null <<'YAML'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'AIMusubi'
    static_configs:
      - targets: ['localhost:5055']
YAML

# ---------- Grafana dashboard provisioning ----------
echo "[*] Creating Grafana provisioning for AIMusubi dashboards..."

GRAFANA_PROV_DIR="/etc/grafana/provisioning/dashboards/aimusubi"
mkdir -p "$GRAFANA_PROV_DIR"

# Provisioning configuration YAML
tee /etc/grafana/provisioning/dashboards/aimusubi.yaml >/dev/null <<'EOF'
apiVersion: 1

providers:
  - name: 'AIMusubi Dashboards'
    orgId: 1
    folder: 'AIMusubi'
    type: file
    disableDeletion: false
    editable: true
    updateIntervalSeconds: 30
    options:
      path: /etc/grafana/provisioning/dashboards/aimusubi
EOF

# Example dashboard 1: AIMusubi Overview
tee "$GRAFANA_PROV_DIR/aimusubi_overview.json" >/dev/null <<'EOF'
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "gnetId": null,
  "graphTooltip": 0,
  "id": null,
  "iteration": 1650000000000,
  "panels": [
    {
      "type": "stat",
      "title": "API Hits / Second",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "rate(AIMusubi_api_hits_total[1m])"
        }
      ],
      "gridPos": { "x": 0, "y": 0, "w": 6, "h": 4 }
    },
    {
      "type": "stat",
      "title": "API Latency (95th percentile)",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "histogram_quantile(0.95, sum(rate(AIMusubi_req_seconds_bucket[5m])) by (le))"
        }
      ],
      "gridPos": { "x": 6, "y": 0, "w": 6, "h": 4 }
    },
    {
      "type": "stat",
      "title": "Last Error Timestamp",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "AIMusubi_last_error_ts"
        }
      ],
      "gridPos": { "x": 0, "y": 4, "w": 6, "h": 4 }
    },
    {
      "type": "stat",
      "title": "Current AIMusubi Level",
      "datasource": "Prometheus",
      "targets": [
        {
          "expr": "AIMusubi_level"
        }
      ],
      "gridPos": { "x": 6, "y": 4, "w": 6, "h": 4 }
    }
  ],
  "refresh": "10s",
  "schemaVersion": 37,
  "style": "dark",
  "tags": ["AIMusubi"],
  "timezone": "",
  "title": "AIMusubi Overview",
  "version": 1
}
EOF

echo "[*] Grafana dashboards provisioned."

echo "[*] Creating Grafana Prometheus datasource..."
mkdir -p /etc/grafana/provisioning/datasources
tee /etc/grafana/provisioning/datasources/prometheus.yaml >/dev/null <<'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
EOF


# ---------- Open WebUI (PyPI install) ----------
echo "[*] Setting up Open WebUI via PyPI..."
sudo -u "$USER_NAME" bash -lc "
  set -e
  python3 -m venv '$OPENWEBUI_VENV'
  source '$OPENWEBUI_VENV/bin/activate'
  pip install -U pip
  pip install open-webui
"

# ---------- Open WebUI persistent data dir ----------
echo "[*] Setting up persistent Open WebUI storage..."
mkdir -p /var/lib/open-webui
chown -R "$USER_NAME":"$USER_NAME" /var/lib/open-webui

tee /etc/systemd/system/open-webui.service >/dev/null <<EOF
[Unit]
Description=Open WebUI (for external LLM front-end)
After=network-online.target
Wants=network-online.target

[Service]
User=$USER_NAME
WorkingDirectory=$AIMusubi_HOME
Environment=PATH=$OPENWEBUI_VENV/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin
Environment=OPEN_WEBUI_DATA_DIR=/var/lib/open-webui
# Optional / example envs
#Environment=OLLAMA_BASE_URL=http://127.0.0.1:11434
#Environment=GOOGLE_API_KEY=YOUR_GEMINI_KEY_HERE
#Environment=HTTP_PROXY=http://proxy.example.com:3128
#Environment=HTTPS_PROXY=http://proxy.example.com:3128
#Environment=NO_PROXY=localhost,127.0.0.1
ExecStart=$OPENWEBUI_VENV/bin/open-webui serve --host 0.0.0.0 --port 8081
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# ---------- Enable services ----------
echo "[*] Enabling and starting systemd services..."
systemctl daemon-reload
systemctl enable --now snmptrapd || true
systemctl enable --now AIMusubi-api
systemctl enable --now prometheus
systemctl enable --now grafana-server
systemctl enable --now open-webui
systemctl enable --now opa
systemctl enable --now cron

# ---------- Final checks + enable cron polling ----------
echo "[*] Waiting for AIMusubi API to come up on port $API_PORT..."
for i in {1..30}; do
  if curl -s "http://127.0.0.1:${API_PORT}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done || true

echo "[*] NOTE: Poller is available but NOT enabled by default."
echo "    To enable cron-based polling later, run:"
echo "      curl -s -X POST http://127.0.0.1:${API_PORT}/scheduler/cron/set \\"
echo "        -H 'Content-Type: application/json' -d '{\"interval_min\":1}'"

# echo "[*] Enabling autonomous polling via cron (every 1 minute)..."
# sudo -u "$USER_NAME" bash -lc "
#  curl -s -X POST http://127.0.0.1:${API_PORT}/scheduler/cron/set \
#    -H 'Content-Type: application/json' \
#    -d '{\"interval_min\":1}' >/dev/null 2>&1 || true
#"

echo
echo "======================================================="
echo "[OK] AIMusubi L5 Unified Full Stack Bootstrap complete."
echo
echo "Core API:     http://127.0.0.1:${API_PORT}/health"
echo "Docs:         http://127.0.0.1:${API_PORT}/docs"
echo "Metrics:      http://127.0.0.1:${API_PORT}/metrics"
echo
echo "Prometheus:   http://127.0.0.1:9090"
echo "Grafana:      http://127.0.0.1:3000"
echo "Open WebUI:   http://127.0.0.1:8081"
echo
echo "NOTE:"
echo " - AIMusubi_HOME: $AIMusubi_HOME"
echo " - Adapters dir:  $ADAPT_DIR"
echo " - Tasks dir:     $TASKS_DIR"
echo " - Tools dir:     $TOOLS_DIR"
echo "======================================================="
