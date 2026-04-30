# 构建指南

## 从头构建的完整步骤

### 1. 安装 Java JDK 17

```powershell
winget install Amazon.Corretto.17.JDK
```

验证：`java -version` 应显示 17.0.x

### 2. 安装 Android SDK

```bash
# 使用 android CLI 安装
android sdk install platform-tools "build-tools/36.1.0" "platforms/android-35" "cmdline-tools/11.0"

# 接受许可
yes | sdkmanager --licenses
```

环境变量：
```bash
export ANDROID_HOME="$HOME/AppData/Local/Android/Sdk"
export JAVA_HOME="/c/Program Files/Amazon Corretto/jdk17.0.19_10"
```

### 3. 安装 Flutter SDK

```bash
git clone https://github.com/flutter/flutter.git -b stable --depth 1 /d/flutter
export PATH="/d/flutter/bin:$PATH"
flutter doctor
```

### 4. 安装依赖

```bash
cd class/
flutter pub get
```

### 5. 构建 APK

```bash
flutter build apk --release
```

输出：`build/app/outputs/flutter-apk/app-release.apk`

### 6. 安装到设备

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

## 常见问题

| 问题 | 解决 |
|------|------|
| "plugins require symlink support" | 开启 Windows 开发者模式 |
| NDK license not accepted | `yes \| sdkmanager --licenses` |
| NDK source.properties missing | 删除 `$ANDROID_HOME/ndk/` 重试 |
| Kotlin daemon compilation failed | `flutter clean` 后重试 |
| Lint: MainActivity not Activity | 清除构建缓存后重试 |
| HTTP 429 from dl.google.com | 高频下载触发了限流，等几分钟 |
