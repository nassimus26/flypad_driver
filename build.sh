#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}      Building Parrot Flypad Driver (Release)       ${NC}"
echo -e "${BLUE}====================================================${NC}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MAC_DIR="${SCRIPT_DIR}/FlypadDriverMac"
OUTPUT_DIR="${SCRIPT_DIR}/dist"
APP_NAME="FlypadDriverMac.app"

if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild is not installed or not in PATH.${NC}"
    exit 1
fi

echo -e "${GREEN}==> Cleaning old build output...${NC}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

echo -e "${GREEN}==> Compiling Release build via xcodebuild...${NC}"
cd "${MAC_DIR}"

xcodebuild -project "FlypadDriverMac.xcodeproj" \
           -scheme "FlypadDriverMac" \
           -configuration Release \
           -derivedDataPath "${MAC_DIR}/build" \
           CODE_SIGNING_ALLOWED=NO \
           build

BUILT_APP_PATH="${MAC_DIR}/build/Build/Products/Release/FlypadDriverMac.app"

if [ ! -d "${BUILT_APP_PATH}" ]; then
    echo -e "${RED}Error: Compiled application not found at ${BUILT_APP_PATH}${NC}"
    exit 1
fi

echo -e "${GREEN}==> Packaging application into dist/...${NC}"
cp -R "${BUILT_APP_PATH}" "${OUTPUT_DIR}/${APP_NAME}"

echo -e "${GREEN}==> Applying local ad-hoc code signature...${NC}"
codesign --force --deep --sign - "${OUTPUT_DIR}/${APP_NAME}"

echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN} SUCCESS: ${APP_NAME} generated in release mode!${NC}"
echo -e "${BLUE} Location: ${OUTPUT_DIR}/${APP_NAME}${NC}"
echo -e "${BLUE}====================================================${NC}"
