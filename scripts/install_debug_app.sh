#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
SRC_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
PROJECT_PATH="$SRC_ROOT/fliggy-agents.xcodeproj"
DERIVED_DATA_PATH="$SRC_ROOT/.build/install-debug"
APP_NAME="fliggy agents.app"
BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug/$APP_NAME"
INSTALL_PATH="$HOME/Applications/$APP_NAME"

mkdir -p "$HOME/Applications"

/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme FliggyAgents \
  -configuration Debug \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  build

if [[ ! -d "$BUILT_APP_PATH" ]]; then
  echo "Built app not found at $BUILT_APP_PATH" >&2
  exit 1
fi

if [[ -d "$INSTALL_PATH" ]]; then
  BACKUP_PATH="$INSTALL_PATH.backup-$(date +%Y%m%d-%H%M%S)"
  mv "$INSTALL_PATH" "$BACKUP_PATH"
  echo "Backed up existing app to $BACKUP_PATH"
fi

ditto "$BUILT_APP_PATH" "$INSTALL_PATH"
xattr -dr com.alibaba.security.edr.antivirus.cloudquery "$INSTALL_PATH" 2>/dev/null || true

echo "Installed Debug build to $INSTALL_PATH"
