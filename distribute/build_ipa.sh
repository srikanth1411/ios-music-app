#!/usr/bin/env bash
# =============================================================================
# build_ipa.sh — Archive & export the MusicAppSwift Ad-Hoc IPA
# =============================================================================
# USAGE:  cd /path/to/MusicAppSwift && bash distribute/build_ipa.sh
#
# REQUIREMENTS:
#   • Xcode command-line tools installed  (xcode-select --install)
#   • Active Apple Developer account signed into Xcode
#   • An Ad-Hoc provisioning profile that includes the target device UDID(s)
#     created at: https://developer.apple.com/account/resources/profiles/list
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="MusicAppSwift"
SCHEME="MusicAppSwift"
BUNDLE_ID="com.srikanth.MusicAppSwift"

ARCHIVE_PATH="/tmp/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="/tmp/${PROJECT_NAME}_export"
EXPORT_OPTIONS="${SCRIPT_DIR}/export_options.plist"
DIST_DIR="${SCRIPT_DIR}"

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warning() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Pre-flight checks ─────────────────────────────────────────────────────────
info "Checking prerequisites..."
command -v xcodebuild &>/dev/null || error "xcodebuild not found. Install Xcode."
[ -f "${EXPORT_OPTIONS}" ]        || error "export_options.plist not found at ${EXPORT_OPTIONS}"

# ── Clean old artifacts ───────────────────────────────────────────────────────
info "Cleaning previous build artifacts..."
rm -rf "${ARCHIVE_PATH}" "${EXPORT_PATH}"

# ── Step 1: Archive ───────────────────────────────────────────────────────────
info "Archiving ${PROJECT_NAME} (this may take a minute)..."
BUILD_LOG="/tmp/${PROJECT_NAME}_build.log"

xcodebuild archive \
  -project "${PROJECT_ROOT}/${PROJECT_NAME}.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "${ARCHIVE_PATH}" \
  CODE_SIGN_STYLE=Automatic \
  2>&1 | tee "${BUILD_LOG}"

# Verify archive was actually created (build may have silently failed)
if [ ! -d "${ARCHIVE_PATH}" ]; then
  echo ""
  error "Archive was not created. Check the build log above for details.\n       Full log saved to: ${BUILD_LOG}"
fi

info "Archive created at: ${ARCHIVE_PATH}"

# ── Step 2: Export IPA ────────────────────────────────────────────────────────
info "Exporting Ad-Hoc IPA..."
xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS}"

# ── Step 3: Copy IPA into distribute/ ────────────────────────────────────────
IPA_SRC=$(find "${EXPORT_PATH}" -name "*.ipa" | head -1)
[ -z "${IPA_SRC}" ] && error "IPA not found in export output. Check signing config."

cp "${IPA_SRC}" "${DIST_DIR}/${PROJECT_NAME}.ipa"
IPA_SIZE=$(du -sh "${DIST_DIR}/${PROJECT_NAME}.ipa" | cut -f1)

echo ""
echo -e "${GREEN}✅ IPA built successfully!${NC}"
echo -e "   Path: ${DIST_DIR}/${PROJECT_NAME}.ipa"
echo -e "   Size: ${IPA_SIZE}"
echo ""
echo -e "${YELLOW}Next step:${NC} Run  bash distribute/serve.sh  to start the OTA server."
