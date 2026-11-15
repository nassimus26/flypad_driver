#!/bin/bash
set -e

# Colors for terminal output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}       Building Parrot Flypad macOS App Bundle      ${NC}"
echo -e "${BLUE}====================================================${NC}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MAC_DIR="${SCRIPT_DIR}/FlypadDriverMac"
OUTPUT_DIR="${SCRIPT_DIR}/dist"
APP_NAME="FlypadDriverMac.app"

# Ensure Xcode command line tools / xcodebuild are available
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild is not installed or not in PATH.${NC}"
    exit 1
fi

echo -e "${GREEN}==> Cleaning previous build artifacts...${NC}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

echo -e "${GREEN}==> Compiling macOS app using xcodebuild (Release configuration)...${NC}"
cd "${MAC_DIR}"

xcodebuild -project "FlypadDriverMac.xcodeproj" \
           -scheme "FlypadDriverMac" \
           -configuration Release \
           -derivedDataPath "${MAC_DIR}/build" \
           CODE_SIGNING_ALLOWED=NO \
           build

BUILT_APP_PATH="${MAC_DIR}/build/Build/Products/Release/FlypadDriverMac.app"

if [ ! -d "${BUILT_APP_PATH}" ]; then
    echo -e "${RED}Error: Build succeeded but ${BUILT_APP_PATH} was not found.${NC}"
    exit 1
fi

echo -e "${GREEN}==> Creating standalone application bundle...${NC}"
cp -R "${BUILT_APP_PATH}" "${OUTPUT_DIR}/${APP_NAME}"

# Sign with a stable identity so macOS privacy permissions (Accessibility) survive rebuilds.
# Ad-hoc signatures change on every build, which makes macOS forget the permission.
SIGN_ID=$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')
if [ -n "${SIGN_ID}" ]; then
    echo -e "${GREEN}==> Signing with stable identity: ${SIGN_ID}${NC}"
    codesign --force --deep --options runtime --sign "${SIGN_ID}" "${OUTPUT_DIR}/${APP_NAME}"
else
    echo -e "${RED}==> No signing certificate found, falling back to ad-hoc (permissions reset on each rebuild)${NC}"
    codesign --force --deep --sign - "${OUTPUT_DIR}/${APP_NAME}"
fi

echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN} SUCCESS: ${APP_NAME} generated successfully!${NC}"
echo -e "${BLUE} Application path: ${OUTPUT_DIR}/${APP_NAME}${NC}"
echo -e "${BLUE}====================================================${NC}"
echo -e "To launch the app:"
echo -e "  open \"${OUTPUT_DIR}/${APP_NAME}\""
echo -e "To move to Applications folder:"
echo -e "  cp -R \"${OUTPUT_DIR}/${APP_NAME}\" /Applications/"
