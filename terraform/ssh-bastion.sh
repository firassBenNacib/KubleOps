#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-up}"

KEY_PATH="${KEY_PATH:-$HOME/.ssh/kubleops.pem}"       
BASTION_KEY_PATH="${BASTION_KEY_PATH:-$KEY_PATH}"      
BASTION_USER="${BASTION_USER:-ec2-user}"                 
TARGET_USER="${TARGET_USER:-ubuntu}"

PORT_ARGOCD="${PORT_ARGOCD:-8443}"
PORT_GRAFANA="${PORT_GRAFANA:-3000}"
PORT_PROM="${PORT_PROM:-9090}"

BASTION_PUBLIC_IP="${BASTION_PUBLIC_IP:-$(terraform output -raw bastion_public_ip 2>/dev/null || true)}"
TARGET_PRIVATE_IP="${TARGET_PRIVATE_IP:-$(terraform output -raw ec2_private_ip 2>/dev/null || true)}"

[[ -n "$BASTION_PUBLIC_IP" && -n "$TARGET_PRIVATE_IP" ]] || { echo "[ERROR] Missing bastion/target IPs."; exit 1; }
[[ -f "$KEY_PATH" ]] || { echo "[ERROR] Key not found at $KEY_PATH"; exit 1; }
[[ -f "$BASTION_KEY_PATH" ]] || { echo "[ERROR] Bastion key not found at $BASTION_KEY_PATH"; exit 1; }
chmod 400 "$KEY_PATH" "$BASTION_KEY_PATH" || true

FORWARDS=(
  "${PORT_ARGOCD}:localhost:8443"
  "${PORT_GRAFANA}:localhost:3000"
  "${PORT_PROM}:localhost:9090"
)
PORTS=("$PORT_ARGOCD" "$PORT_GRAFANA" "$PORT_PROM")

signature() { echo "ssh .* ${TARGET_USER}@${TARGET_PRIVATE_IP} .*ProxyCommand=ssh -i ${BASTION_KEY_PATH} .* ${BASTION_USER}@${BASTION_PUBLIC_IP}"; }

is_listening(){ lsof -ti tcp:"$1" -sTCP:LISTEN >/dev/null 2>&1 || ss -ltn 2>/dev/null | grep -qE "[^0-9]$1\\s"; }
kill_port(){ lsof -ti tcp:"$1" -sTCP:LISTEN 2>/dev/null | xargs -r kill || pkill -f "ssh .*localhost:${1}" || true; }

start() {
  for p in "${PORTS[@]}"; do
    if is_listening "$p"; then
      echo "[WARN] Port $p is already in use locally. Run: $0 down  (or change PORT_* env vars)"; exit 1
    fi
  done
  LFLAGS=(); for f in "${FORWARDS[@]}"; do LFLAGS+=(-L "$f"); done

  echo "[INFO] Starting tunnel → Bastion ${BASTION_PUBLIC_IP} → Target ${TARGET_PRIVATE_IP}"
  ssh -f -N \
    -i "$KEY_PATH" \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -o StrictHostKeyChecking=accept-new \
    -o "ProxyCommand=ssh -i ${BASTION_KEY_PATH} -o StrictHostKeyChecking=accept-new -W %h:%p ${BASTION_USER}@${BASTION_PUBLIC_IP}" \
    "${LFLAGS[@]}" \
    "${TARGET_USER}@${TARGET_PRIVATE_IP}"
  status
}

stop() {
  pkill -f "$(signature)" || true
  for p in "${PORTS[@]}"; do kill_port "$p"; done
  echo "[OK] Tunnel stopped."
}

status() {
  echo "[STATUS] Local listeners:"
  ss -ltnp 2>/dev/null | grep -E ":((${PORTS[0]}|${PORTS[1]}|${PORTS[2]}))\s" || true
  if pgrep -f "$(signature)" >/dev/null; then echo "[OK] Tunnel process detected."; else echo "[INFO] No tunnel process."; fi
}

shell() {
  echo "[INFO] Opening interactive shell on target via bastion…"
  exec ssh \
    -i "$KEY_PATH" \
    -o StrictHostKeyChecking=accept-new \
    -o "ProxyCommand=ssh -i ${BASTION_KEY_PATH} -o StrictHostKeyChecking=accept-new -W %h:%p ${BASTION_USER}@${BASTION_PUBLIC_IP}" \
    "${TARGET_USER}@${TARGET_PRIVATE_IP}"
}

case "${CMD}" in
  up|start)    start ;;
  down|stop)   stop ;;
  restart)     stop; sleep 1; start ;;
  status)      status ;;
  shell|ssh)   shell ;;
  *) echo "Usage: $0 {up|down|restart|status|shell}"; exit 2;;
esac
