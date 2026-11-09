#!/bin/bash

# Build librcheevos for iOS and iOS Simulator.
# Usage: ./build_ios.sh [target] [--copy] [--no-copy]
# target: device | simulator | all (default: all)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ "$(uname)" != "Darwin" ]]; then
  echo "错误: iOS 构建只能在 macOS 系统上进行"
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "错误: 找不到 xcrun，请确保已安装 Xcode"
  exit 1
fi

TARGET="all"
AUTO_COPY_FLAG=""
NO_COPY_FLAG=""

for arg in "$@"; do
  case "$arg" in
    --copy)
      AUTO_COPY_FLAG="--copy"
      ;;
    --no-copy)
      NO_COPY_FLAG="--no-copy"
      ;;
    device|simulator|all)
      TARGET="$arg"
      ;;
    -h|--help)
      echo "用法: $0 [target] [--copy] [--no-copy]"
      echo ""
      echo "target:"
      echo "  device     - 仅构建 iOS 真机 arm64"
      echo "  simulator  - 仅构建 iOS 模拟器 arm64"
      echo "  all        - 构建全部（默认）"
      exit 0
      ;;
  esac
done

CPU_CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)

SRC_FILES=(
  ../src/rc_client.c
  ../src/rc_client_external.c
  ../src/rc_client_raintegration.c
  ../src/rc_compat.c
  ../src/rc_util.c
  ../src/rc_version.c
  ../src/rcheevos/alloc.c
  ../src/rcheevos/condition.c
  ../src/rcheevos/condset.c
  ../src/rcheevos/consoleinfo.c
  ../src/rcheevos/format.c
  ../src/rcheevos/lboard.c
  ../src/rcheevos/memref.c
  ../src/rcheevos/operand.c
  ../src/rcheevos/richpresence.c
  ../src/rcheevos/runtime.c
  ../src/rcheevos/runtime_progress.c
  ../src/rcheevos/trigger.c
  ../src/rcheevos/value.c
  ../src/rhash/aes.c
  ../src/rhash/cdreader.c
  ../src/rhash/hash.c
  ../src/rhash/hash_disc.c
  ../src/rhash/hash_encrypted.c
  ../src/rhash/hash_rom.c
  ../src/rhash/hash_zip.c
  ../src/rhash/md5.c
  ../src/rapi/rc_api_common.c
  ../src/rapi/rc_api_editor.c
  ../src/rapi/rc_api_info.c
  ../src/rapi/rc_api_runtime.c
  ../src/rapi/rc_api_user.c
)

build_ios_target() {
  local sdk="$1"
  local arch="$2"
  local min_flag="$3"
  local output="$4"

  local sdk_path
  sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
  local cc
  cc="$(xcrun --sdk "$sdk" --find clang)"

  mkdir -p "$(dirname "$output")"

  echo "构建 $sdk ($arch) -> $output"
  "$cc" -dynamiclib \
    -arch "$arch" \
    -isysroot "$sdk_path" \
    "$min_flag" \
    -fPIC \
    -O2 \
    -g \
    -fvisibility=hidden \
    -ffunction-sections \
    -fdata-sections \
    -DRC_SHARED \
    -D__STDC_FORMAT_MACROS \
    -I../include \
    -I../src \
    "${SRC_FILES[@]}" \
    -Wl,-dead_strip \
    -Wl,-install_name,@rpath/librcheevos.framework/librcheevos \
    -lz \
    -o "$output"
}

case "$TARGET" in
  device)
    build_ios_target "iphoneos" "arm64" "-miphoneos-version-min=15.0" "$SCRIPT_DIR/libs/ios-arm64/librcheevos.dylib"
    ;;
  simulator)
    build_ios_target "iphonesimulator" "arm64" "-mios-simulator-version-min=15.0" "$SCRIPT_DIR/libs/ios-simulator-arm64/librcheevos.dylib"
    ;;
  all)
    build_ios_target "iphoneos" "arm64" "-miphoneos-version-min=15.0" "$SCRIPT_DIR/libs/ios-arm64/librcheevos.dylib"
    build_ios_target "iphonesimulator" "arm64" "-mios-simulator-version-min=15.0" "$SCRIPT_DIR/libs/ios-simulator-arm64/librcheevos.dylib"
    ;;
  *)
    echo "错误: 未知 target: $TARGET"
    exit 1
    ;;
esac

echo ""
echo "构建完成！"
echo "输出文件:"
echo "  真机:   libs/ios-arm64/librcheevos.dylib"
echo "  模拟器: libs/ios-simulator-arm64/librcheevos.dylib"

if [[ "$AUTO_COPY" == "1" ]] || [[ -n "$AUTO_COPY_FLAG" ]]; then
  echo ""
  echo "自动复制库文件到 go_gba 项目目录..."
  if [ -f "$SCRIPT_DIR/copy_libs.sh" ]; then
    "$SCRIPT_DIR/copy_libs.sh" ios
  else
    echo "警告: 找不到 copy_libs.sh 脚本"
  fi
elif [[ -z "$NO_COPY_FLAG" ]]; then
  echo ""
  echo "提示: 使用 './copy_libs.sh ios' 复制库文件到 go_gba 项目目录"
  echo "     或运行构建脚本时添加 --copy 参数自动复制"
fi
