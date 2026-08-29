#!/usr/bin/env bash
# =============================================================================
# Nature Fete — one-command VPS deployment
#
#   sudo ./deploy.sh api.yourdomain.com
#
# What it does on a fresh Ubuntu 22.04/24.04 server:
#   1. installs Docker (if missing)
#   2. asks for the three secrets (or reuses deploy/.env if present)
#   3. builds & starts: Nature Fete API + Caddy with automatic HTTPS
#   4. verifies the health endpoint on https://<your-domain>/api/health
#
# Run from the repo root:  sudo ./deploy/deploy.sh api.yourdomain.com
# =============================================================================
set -euo pipefail

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  echo "Usage: sudo ./deploy.sh api.yourdomain.com"
  exit 1
fi
cd "$(dirname "$0")"

# ---------- 1. Docker ----------
if ! command -v docker >/dev/null 2>&1; then
  echo "▸ Installing Docker…"
  curl -fsSL https://get.docker.com | sh
fi
docker compose version >/dev/null 2>&1 || {
  echo "✗ Docker Compose plugin missing — install Docker manually: https://docs.docker.com/engine/install/"
  exit 1
}

# ---------- 2. Secrets ----------
if [ ! -f .env ]; then
  echo "▸ First run — copying your secrets from Render (dashboard → luxefeast-api → Environment):"
  read -rp "  DATABASE_URL (Neon connection string): " DB_URL
  read -rp "  JWT_SECRET  (copy EXACTLY from Render — keeps everyone logged in): " JWT
  echo "  FIREBASE_SERVICE_ACCOUNT (paste the whole service-account JSON, then press Enter):"
  read -rsrp "  > " FIREBASE
  FIREBASE=$(echo "$FIREBASE" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  cat > .env <<EOF
API_DOMAIN=$DOMAIN
DATABASE_URL=$DB_URL
JWT_SECRET=$JWT
FIREBASE_SERVICE_ACCOUNT=$FIREBASE
EOF
  chmod 600 .env
  echo "  saved to deploy/.env (kept secret, never committed)"
else
  echo "▸ Reusing existing deploy/.env"
fi

# ---------- 3. Launch ----------
echo "▸ Building & starting (API + Caddy HTTPS)…"
docker compose up -d --build

# ---------- 4. Verify ----------
echo "▸ Waiting for the API to come up…"
for i in $(seq 1 30); do
  if curl -fs "http://localhost:5000/api/health" >/dev/null 2>&1; then break; fi
  sleep 2
done

echo
echo "============================================================"
echo "  If this shows healthy — you are LIVE:"
echo "    https://$DOMAIN/api/health"
echo
echo "  (First HTTPS certificate issue can take ~60s.)"
echo
echo "  Logs:      docker compose logs -f api"
echo "  Restart:   docker compose restart"
echo "  Update:    git pull && docker compose up -d --build"
echo "============================================================"
curl -fs "https://$DOMAIN/api/health" && echo || true
