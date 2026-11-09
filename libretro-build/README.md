# rcheevos libretro-build helper

对齐 `libretro-mgba/libretro-build` 的本地构建与替换流程，用于把 `librcheevos` 编译产物同步到 `go_gba`。

## 输出目录

- Android stripped: `libs/arm64-v8a/librcheevos.so`
- Android unstripped: `obj/local/arm64-v8a/librcheevos.so`
- iOS device: `libs/ios-arm64/librcheevos.dylib`
- iOS simulator: `libs/ios-simulator-arm64/librcheevos.dylib`

## 用法

```bash
cd rcheevos/libretro-build

# Android arm64-v8a（支持 --copy 自动替换到 go_gba）
./build_android_arm64.sh /path/to/android-ndk --copy

# iOS 真机+模拟器（支持 --copy 自动替换到 go_gba）
./build_ios.sh all --copy

# 仅复制现有产物
./copy_libs.sh all
```

## 同步目标（go_gba）

- Android 打包库：`go_gba/android/app/src/main/jniLibs/arm64-v8a/librcheevos.so`
- Android Crashlytics 符号库（unstripped）：`go_gba/android/app/src/main/symbols/arm64-v8a/librcheevos.so`
- iOS XCFramework：
  - `go_gba/ios/Runner/librcheevos.xcframework/ios-arm64/librcheevos.framework/librcheevos`
  - `go_gba/ios/Runner/librcheevos.xcframework/ios-simulator-arm64/librcheevos.framework/librcheevos`

> Android 同步 unstripped 版本用于 Crashlytics Native 符号化，便于还原发布版本崩溃堆栈（与 Dart 混淆符号上传流程互补）。
