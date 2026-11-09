#!/bin/bash

# Build librcheevos.so for Android arm64-v8a.
# Usage: ./build_android_arm64.sh [NDK_PATH] [--copy] [--no-copy]
# Or set env: ANDROID_NDK=/path/to/android-ndk

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

AUTO_COPY_FLAG=""
NO_COPY_FLAG=""
NDK_PATH=""

for arg in "$@"; do
  case "$arg" in
    --copy)
      AUTO_COPY_FLAG="--copy"
      ;;
    --no-copy)
      NO_COPY_FLAG="--no-copy"
      ;;
    *)
      if [ -z "$NDK_PATH" ] && [ -n "$arg" ]; then
        NDK_PATH="$arg"
      fi
      ;;
  esac
done

if [ -z "$NDK_PATH" ]; then
  if [ -n "$ANDROID_NDK" ]; then
    NDK_PATH="$ANDROID_NDK"
  elif [ -n "$NDK_ROOT" ]; then
    NDK_PATH="$NDK_ROOT"
  else
    echo "错误: 请提供 Android NDK 路径"
    echo "用法: $0 [NDK路径] [--copy] [--no-copy]"
    echo "或者设置环境变量: export ANDROID_NDK=/path/to/android-ndk"
    exit 1
  fi
fi

if [ ! -d "$NDK_PATH" ]; then
  echo "错误: NDK 路径不存在: $NDK_PATH"
  exit 1
fi

HOST_TAG="darwin-x86_64"
if [ ! -d "$NDK_PATH/toolchains/llvm/prebuilt/$HOST_TAG" ]; then
  HOST_TAG="darwin-arm64"
fi

TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/$HOST_TAG/bin"
CC="$TOOLCHAIN/aarch64-linux-android21-clang"

if [ ! -x "$CC" ]; then
  echo "错误: 找不到 Android clang 编译器: $CC"
  exit 1
fi

echo "使用 NDK: $NDK_PATH"
echo "使用 Toolchain: $TOOLCHAIN"
echo "开始构建 Android arm64-v8a 的 librcheevos.so..."
echo ""

mkdir -p "$SCRIPT_DIR/obj/local/arm64-v8a"

UNSTRIPPED_OUT="$SCRIPT_DIR/obj/local/arm64-v8a/librcheevos.so"

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

CFLAGS=(
  -fPIC
  -O2
  -g
  -fvisibility=hidden
  -ffunction-sections
  -fdata-sections
  -DRC_SHARED
  -D__STDC_FORMAT_MACROS
  -I../include
  -I../src
)

LDFLAGS=(
  -shared
  -Wl,--gc-sections
  -Wl,-soname,librcheevos.so
  # Raw clang adds no build ID (ndk-build/cmake do); Crashlytics needs it to
  # match native crashes to the uploaded symbols.
  -Wl,--build-id=sha1
  -llog
  -lz
)

"$CC" "${CFLAGS[@]}" "${SRC_FILES[@]}" "${LDFLAGS[@]}" -o "$UNSTRIPPED_OUT"

echo ""
echo "构建完成！"
echo "未 strip 输出: $UNSTRIPPED_OUT"

if [[ "$AUTO_COPY" == "1" ]] || [[ -n "$AUTO_COPY_FLAG" ]]; then
  echo ""
  echo "自动复制库文件到 go_gba 项目目录..."
  if [ -f "$SCRIPT_DIR/copy_libs.sh" ]; then
    "$SCRIPT_DIR/copy_libs.sh" android
  else
    echo "警告: 找不到 copy_libs.sh 脚本"
  fi
elif [[ -z "$NO_COPY_FLAG" ]]; then
  echo ""
  echo "提示: 使用 './copy_libs.sh android' 复制库文件到 go_gba 项目目录"
  echo "     或运行构建脚本时添加 --copy 参数自动复制"
fi
