#!/usr/bin/env bash
# =============================================================================
# serve.sh — Start local HTTPS server + ngrok tunnel for OTA distribution
# =============================================================================
# USAGE:  bash distribute/serve.sh
#
# REQUIREMENTS:
#   • MusicAppSwift.ipa must exist in distribute/ (run build_ipa.sh first)
#   • ngrok installed: brew install ngrok
#   • FREE ngrok account + authtoken (required since ngrok v3):
#       1. Sign up at https://dashboard.ngrok.com/signup
#       2. Get your token at https://dashboard.ngrok.com/get-started/your-authtoken
#       3. Run: ngrok config add-authtoken <your-token>
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=8080
IPA="${SCRIPT_DIR}/MusicAppSwift.ipa"
MANIFEST="${SCRIPT_DIR}/manifest.plist"
MANIFEST_BACKUP="${SCRIPT_DIR}/manifest.plist.bak"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}$*${NC}\n"; }

# ── Pre-flight checks ─────────────────────────────────────────────────────────
header "🎵 MusicAppSwift OTA Server"

[ -f "${IPA}" ] || error "IPA not found: ${IPA}\n       Run:  bash distribute/build_ipa.sh  first."
command -v ngrok &>/dev/null || error "ngrok not found.\n       Install with:  brew install ngrok"
command -v python3 &>/dev/null || error "python3 not found. Install Xcode command line tools."

# Check if ngrok has an authtoken configured (required since ngrok v3)
if ! ngrok config check &>/dev/null 2>&1 || ! grep -q "authtoken" "${HOME}/Library/Application Support/ngrok/ngrok.yml" 2>/dev/null; then
  echo ""
  echo -e "${RED}[ERROR]${NC} ngrok requires a free account and authtoken."
  echo -e "        Follow these 3 steps:\n"
  echo -e "  ${BOLD}1. Sign up (free):${NC}  https://dashboard.ngrok.com/signup"
  echo -e "  ${BOLD}2. Get your token:${NC}  https://dashboard.ngrok.com/get-started/your-authtoken"
  echo -e "  ${BOLD}3. Run this:${NC}        ngrok config add-authtoken <YOUR_TOKEN>\n"
  echo -e "  Then run this script again."
  echo ""
  exit 1
fi

# ── Restore original manifest (in case previous run exited uncleanly) ─────────
if [ -f "${MANIFEST_BACKUP}" ]; then
  cp "${MANIFEST_BACKUP}" "${MANIFEST}"
  rm "${MANIFEST_BACKUP}"
fi

# ── Clean up on exit ──────────────────────────────────────────────────────────
cleanup() {
  echo ""
  info "Shutting down..."
  # Restore manifest to original template state
  if [ -f "${MANIFEST_BACKUP}" ]; then
    cp "${MANIFEST_BACKUP}" "${MANIFEST}"
    rm "${MANIFEST_BACKUP}"
    info "manifest.plist restored to template."
  fi
  # Kill background processes
  kill "${NGROK_PID}" 2>/dev/null || true
  kill "${SERVER_PID}" 2>/dev/null || true
  info "Server stopped. Goodbye! 👋"
}
trap cleanup EXIT INT TERM

# ── Start local HTTP server ───────────────────────────────────────────────────
info "Starting local HTTP server on port ${PORT}..."
cd "${SCRIPT_DIR}"
python3 -m http.server ${PORT} &>/dev/null &
SERVER_PID=$!
sleep 1
info "Local server: http://localhost:${PORT}"

# ── Start ngrok tunnel ────────────────────────────────────────────────────────
info "Starting ngrok tunnel..."
ngrok http ${PORT} --log=stdout --log-format=json > /tmp/ngrok_ota.log 2>&1 &
NGROK_PID=$!

# Wait for ngrok to establish the tunnel (up to 15 seconds)
NGROK_URL=""
for i in $(seq 1 30); do
  sleep 0.5
  NGROK_URL=$(grep -o '"public_url":"https:[^"]*"' /tmp/ngrok_ota.log 2>/dev/null \
              | head -1 | sed 's/"public_url":"//;s/"//' || true)
  [ -n "${NGROK_URL}" ] && break
done

if [ -z "${NGROK_URL}" ]; then
  # Check specifically for auth failure
  if grep -q "ERR_NGROK_4018" /tmp/ngrok_ota.log 2>/dev/null; then
    echo ""
    echo -e "${RED}[ERROR]${NC} ngrok authentication failed (ERR_NGROK_4018)."
    echo -e "        Sign up at:  https://dashboard.ngrok.com/signup"
    echo -e "        Then run:    ngrok config add-authtoken <YOUR_TOKEN>"
    echo ""
    exit 1
  fi
  error "ngrok failed to start. Full log: /tmp/ngrok_ota.log"
fi

# ── Patch manifest.plist with the real ngrok URL ──────────────────────────────
info "Patching manifest.plist with: ${NGROK_URL}"
cp "${MANIFEST}" "${MANIFEST_BACKUP}"          # save original template
sed -i '' "s|BASE_URL|${NGROK_URL}|g" "${MANIFEST}"

# ── Print QR install URL ──────────────────────────────────────────────────────
MANIFEST_URL="${NGROK_URL}/manifest.plist"
INSTALL_URL="itms-services://?action=download-manifest&url=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${MANIFEST_URL}', safe=''))")"
DOWNLOAD_PAGE="${NGROK_URL}/index.html"

echo ""
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${BOLD}${GREEN}✅  OTA Server is LIVE${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "  ${BOLD}Download page (open this in browser or scan QR):${NC}"
echo -e "  ${CYAN}${DOWNLOAD_PAGE}${NC}"
echo ""
echo -e "  ${BOLD}Direct install URL (paste in Safari on iPhone):${NC}"
echo -e "  ${CYAN}${INSTALL_URL}${NC}"
echo ""
echo -e "  ${BOLD}ngrok dashboard (inspect traffic):${NC}"
echo -e "  ${CYAN}http://localhost:4040${NC}"
echo ""
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${YELLOW}Press Ctrl+C to stop the server${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Try to open the download page in the default browser automatically
open "${DOWNLOAD_PAGE}" 2>/dev/null || true

# ── Keep alive ────────────────────────────────────────────────────────────────
wait "${SERVER_PID}"
