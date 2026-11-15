#!/bin/bash
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_PATH="${SCRIPT_DIR}/dist/FlypadDriverMac.app"

if [ ! -d "${APP_PATH}" ]; then
    echo -e "${BLUE}==> Release build not found. Running build.sh first...${NC}"
    "${SCRIPT_DIR}/build.sh"
fi

echo -e "${GREEN}==> Launching FlypadDriverMac.app...${NC}"
open "${APP_PATH}"
echo -e "${GREEN}App launched successfully!${NC}"
