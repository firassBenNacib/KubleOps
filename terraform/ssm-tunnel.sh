#!/usr/bin/env bash
set -euo pipefail

CMD="${1:-up}"

REGION="${REGION:-us-east-1}"
INSTANCE_ID="${INSTANCE_ID:-}"
NAME_TAG="${NAME_TAG:-KubleOps-server}"
PORT_ARGOCD="${PORT_ARGOCD:-8443}"
PORT_GRAFANA="${PORT_GRAFANA:-3000}"
PORT_PROM="${PORT_PROM:-9090}"
LOG_DIR="${LOG_DIR:-$HOME/.ssm-tunnel}"
PID_DIR="${PID_DIR:-$LOG_DIR/pids}"
mkdir -p "$LOG_DIR" "$PID_DIR"

need() { command -v "$1" >/dev/null 2>&1 || { echo "[ERROR] Missing $1"; exit 1; }; }
need aws

plugin_ok() { aws ssm start-session help >/dev/null 2>&1; }
is_listening(){ lsof -ti tcp:"$1" -sTCP:LISTEN >/dev/null 2>&1 || ss -ltn 2>/dev/null | grep -qE "[^0-9]$1\\s"; }
kill_port(){ lsof -ti tcp:"$1" -sTCP:LISTEN 2>/dev/null | xargs -r kill || pkill -f "session-manager-plugin.*localhost:${1}" || true; }

discover_instance() {
  [[ -n "${INSTANCE_ID}" ]] && return 0
  INSTANCE_ID="$(aws ec2 describe-instances \
     --region "$REGION" \
     --filters "Name=tag:Name,Values=${NAME_TAG}" "Name=instance-state-name,Values=running" \
     --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || true)"
  if [[ -z "${INSTANCE_ID}" || "${INSTANCE_ID}" == "None" ]]; then
    echo "[ERROR] Could not find a running instance with tag Name=${NAME_TAG}. Set INSTANCE_ID env var."; exit 1
  fi
}

start_one() {
  local LPORT="$1" RPORT="$2" NAME="$3"
  if is_listening "$LPORT"; then
    echo "[WARN] Port $LPORT already in use locally; skipping $NAME"
    return
  fi
  echo "[INFO] Starting SSM port-forward $NAME on localhost:${LPORT} -> ${RPORT}"
  nohup aws ssm start-session \
    --region "$REGION" \
    --target "$INSTANCE_ID" \
    --document-name AWS-StartPortForwardingSession \
    --parameters "portNumber=${RPORT},localPortNumber=${LPORT}" \
    >"$LOG_DIR/${NAME}.log" 2>&1 &
  echo $! > "$PID_DIR/${NAME}.pid"
  sleep 1
}

stop_one() {
  local NAME="$1" LPORT="$2"
  if [[ -f "$PID_DIR/${NAME}.pid" ]]; then
    kill "$(cat "$PID_DIR/${NAME}.pid")" 2>/dev/null || true
    rm -f "$PID_DIR/${NAME}.pid"
  fi
  kill_port "$LPORT"
}

status_one() {
  local NAME="$1" LPORT="$2"
  local PID_FILE="$PID_DIR/${NAME}.pid"
  if [[ -f "$PID_FILE" ]] && ps -p "$(cat "$PID_FILE")" >/dev/null 2>&1; then
    echo "[OK] $NAME tunnel running (local $LPORT), pid $(cat "$PID_FILE")"
  else
    echo "[..] $NAME tunnel not running (expected local $LPORT)"
  fi
}

start_all() {
  plugin_ok || { echo "[ERROR] Session Manager plugin missing. See AWS docs."; exit 1; }
  discover_instance
  start_one "$PORT_ARGOCD" 8443 "argocd"
  start_one "$PORT_GRAFANA" 3000 "grafana"
  start_one "$PORT_PROM"    9090 "prometheus"
  status
}

stop_all() {
  stop_one "argocd"   "$PORT_ARGOCD"
  stop_one "grafana"  "$PORT_GRAFANA"
  stop_one "prometheus" "$PORT_PROM"
  echo "[OK] All tunnels stopped."
}

status() {
  status_one "argocd"   "$PORT_ARGOCD"
  status_one "grafana"  "$PORT_GRAFANA"
  status_one "prometheus" "$PORT_PROM"
  echo "[INFO] Logs in $LOG_DIR/*.log"
}

shell_ssm() {
  discover_instance
  echo "[INFO] Opening SSM shell to ${INSTANCE_ID} in ${REGION}..."
  exec aws ssm start-session --region "$REGION" --target "$INSTANCE_ID"
}

case "${CMD}" in
  up|start)    start_all ;;
  down|stop)   stop_all ;;
  restart)     stop_all; sleep 1; start_all ;;
  status)      status ;;
  shell|ssh)   shell_ssm ;;
  *) echo "Usage: $0 {up|down|restart|status|shell} [ENV: REGION, INSTANCE_ID, NAME_TAG, PORT_*]"; exit 2 ;;
esac
