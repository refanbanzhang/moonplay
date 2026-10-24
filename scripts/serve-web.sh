#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-8080}"
HOST="${HOST:-0.0.0.0}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "error: 需要安装 Python 3 才能启动本地网页服务" >&2
  exit 1
fi

echo "Moonplay Web: http://localhost:${PORT}"
echo "局域网访问地址请使用本机 IP，例如：http://192.168.1.10:${PORT}"
echo "按 Ctrl-C 停止服务"

cd "${ROOT}/web"
exec python3 -m http.server "${PORT}" --bind "${HOST}"
