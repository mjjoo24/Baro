#!/bin/bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-debug}"

cd "$PROJECT_ROOT"

echo "==> swift build ($CONFIGURATION)"
if [ "$CONFIGURATION" = "release" ]; then
    BUILD_ARGS="-c release"
else
    BUILD_ARGS=""
fi

find Sources -name '*.swift' -exec touch {} +

if ! swift build $BUILD_ARGS; then
    echo "==> 첫 빌드 실패, 재시도"
    swift build $BUILD_ARGS
fi
BIN_DIR="$(swift build $BUILD_ARGS --show-bin-path)"

APP_NAME="Baro"
APP_BUNDLE="$PROJECT_ROOT/build/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> 번들 구조 생성: $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BIN_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$PROJECT_ROOT/Sources/Baro/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

if [ -f "$PROJECT_ROOT/Sources/Baro/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_ROOT/Sources/Baro/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
else
    echo "⚠️  AppIcon.icns가 없습니다. 'swift Scripts/generate_icon.swift'로 먼저 생성하세요."
fi

SIGN_IDENTITY="${BARO_SIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | grep -m1 -oE '"[^"]+"' | tr -d '"' || true)"
fi

if [ -n "$SIGN_IDENTITY" ]; then
    echo "==> 서명: $SIGN_IDENTITY"
    codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
else
    echo "==> 서명: ad-hoc (유효한 코드사이닝 인증서 없음)"
    codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true
fi

echo "==> 완료: $APP_BUNDLE"
echo "실행: open \"$APP_BUNDLE\""
