#!/bin/bash

# Copy built librcheevos artifacts to go_gba.
# Usage: ./copy_libs.sh [android|ios|all]
# Default: all

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# rcheevos/libretro-build -> rcheevos -> gba -> go_gba
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../go_gba" && pwd)"

BUILD_DIR="$SCRIPT_DIR/libs"
OBJ_DIR="$SCRIPT_DIR/obj/local"

ANDROID_TARGET_DIR="$PROJECT_ROOT/android/app/src/main/jniLibs/arm64-v8a"
# Unstripped on purpose: AGP strips it when packaging and Crashlytics reads
# the symbols from the merged (still unstripped) copy.
ANDROID_SOURCE="$OBJ_DIR/arm64-v8a/librcheevos.so"

IOS_XCFRAMEWORK_DIR="$PROJECT_ROOT/ios/Runner/librcheevos.xcframework"
IOS_DEVICE_SOURCE="$BUILD_DIR/ios-arm64/librcheevos.dylib"
IOS_SIM_ARM64_SOURCE="$BUILD_DIR/ios-simulator-arm64/librcheevos.dylib"

copy_file() {
  local source=$1
  local target=$2
  local description=$3

  if [ ! -f "$source" ]; then
    echo -e "${RED}❌ 错误: 源文件不存在: $source${NC}"
    echo -e "${YELLOW}   提示: 请先运行对应构建脚本${NC}"
    return 1
  fi

  local target_dir
  target_dir="$(dirname "$target")"
  mkdir -p "$target_dir"
  cp "$source" "$target"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} $description"
    echo -e "   ${BLUE}从:${NC} $source"
    echo -e "   ${BLUE}到:${NC} $target"
    return 0
  fi

  echo -e "${RED}✗${NC} $description 复制失败"
  return 1
}

copy_headers_for_slice() {
  local headers_target_dir=$1
  local include_dir="$SCRIPT_DIR/../include"

  if [ ! -d "$include_dir" ]; then
    echo -e "${YELLOW}⚠️  跳过头文件同步: 未找到 $include_dir${NC}"
    return 0
  fi

  mkdir -p "$headers_target_dir"
  cp "$include_dir"/*.h "$headers_target_dir"/
  echo -e "${GREEN}✓${NC} 同步头文件到 $headers_target_dir"
}

copy_android() {
  echo -e "${YELLOW}========================================${NC}"
  echo -e "${YELLOW}复制 Android librcheevos 库文件${NC}"
  echo -e "${YELLOW}========================================${NC}"
  echo ""

  copy_file "$ANDROID_SOURCE" \
            "$ANDROID_TARGET_DIR/librcheevos.so" \
            "Android ARM64 库 (unstripped)"

  echo ""
}

copy_ios() {
  echo -e "${YELLOW}========================================${NC}"
  echo -e "${YELLOW}复制 iOS librcheevos 库文件${NC}"
  echo -e "${YELLOW}========================================${NC}"
  echo ""

  local success_count=0
  local total_count=0

  if [ -f "$IOS_DEVICE_SOURCE" ]; then
    total_count=$((total_count + 1))
    if copy_file "$IOS_DEVICE_SOURCE" \
                 "$IOS_XCFRAMEWORK_DIR/ios-arm64/librcheevos.framework/librcheevos" \
                 "iOS 真机 (arm64) 库"; then
      success_count=$((success_count + 1))
      copy_headers_for_slice "$IOS_XCFRAMEWORK_DIR/ios-arm64/librcheevos.framework/Headers"
    fi
    echo ""
  else
    echo -e "${YELLOW}⚠️  跳过: iOS 真机库不存在${NC}"
    echo ""
  fi

  if [ -f "$IOS_SIM_ARM64_SOURCE" ]; then
    total_count=$((total_count + 1))
    if copy_file "$IOS_SIM_ARM64_SOURCE" \
                 "$IOS_XCFRAMEWORK_DIR/ios-simulator-arm64/librcheevos.framework/librcheevos" \
                 "iOS 模拟器 (arm64) 库"; then
      success_count=$((success_count + 1))
      copy_headers_for_slice "$IOS_XCFRAMEWORK_DIR/ios-simulator-arm64/librcheevos.framework/Headers"
    fi
    echo ""
  else
    echo -e "${YELLOW}⚠️  跳过: iOS 模拟器 arm64 库不存在${NC}"
    echo ""
  fi

  if [ $total_count -eq 0 ]; then
    echo -e "${RED}❌ 错误: 没有找到任何 iOS 库文件${NC}"
    echo -e "${YELLOW}   提示: 请先运行 ./build_ios.sh${NC}"
    return 1
  fi

  if [ $success_count -eq $total_count ]; then
    return 0
  fi

  return 1
}

main() {
  local target="${1:-all}"

  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}复制 librcheevos 到 go_gba${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo ""

  case "$target" in
    android)
      copy_android
      ;;
    ios)
      copy_ios
      ;;
    all)
      copy_android
      copy_ios
      ;;
    *)
      echo -e "${RED}错误: 未知的目标 '$target'${NC}"
      echo ""
      echo "用法: $0 [android|ios|all]"
      exit 1
      ;;
  esac

  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN}复制完成！${NC}"
  echo -e "${GREEN}========================================${NC}"
}

main "$@"
