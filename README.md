# qshy4-t5max

REDMI Turbo 5 Max（dash）的青山护眼 4.0 最小适配模块源码。

仓库里只放**我们自己写的脚本和构建代码**；不包含小米的 APK、XML、固件、日志，
也不提交构建产物。构建时由使用者从自己的手机上读取原始文件。

## 背景

- 机型：REDMI Turbo 5 Max（dash / 2602BRT18C），HyperOS 4 / Android 17。
- 环境：APatch（115404），Magic Mount 处于关闭状态。
- 青山护眼的 4.0 “调节模式”要求版本号 >= 4；这个版本号是
  `com.miui.rom:integer/green_mountain_eyecare_version`。
- Settings 读取的是系统资源（`Resources.getSystem()`），所以单纯新增一个
  更高优先级的独立 Overlay 不会影响它；必须改动原厂
  `/product/overlay/MiuiFrameworkResOverlay.apk` 本身。
- 睡眠护眼由 `dash.xml` 的 `support_night_wakeup_mode_setting` 控制，不依赖版本号。

## 模块做了什么

1. **dash.xml**（构建时 patch 使用者自己的文件）
   - `support_night_wakeup_mode_setting`：`false` → `true`
   - 新增 `enable_eyecare_wave_render`：`true`
   - 其他设备特性原样保留。

2. **原厂 Overlay 的 4 字节克隆**
   - 取 `/product/overlay/MiuiFrameworkResOverlay.apk`。
   - 只把 `resources.arsc` 里 `integer/green_mountain_eyecare_version`
     的 4 字节整数从 `3` 改成 `4`。
   - 包名、versionCode、priority、全部资源、资源 ID，以及数组/浮点值都不变。
   - 重新签名后，用 `post-fs-data.sh` 在 zygote 之前 `mount --bind`
     回原路径，这样 `Resources.getSystem()` 读到的也是 4。
   - 不使用独立 Overlay，也不占用其他 Overlay 槽位。

3. **绕过 APatch 的挂载限制**
   - 因为 Magic Mount 关闭，`post-fs-data.sh` 直接 bind mount：
     - `dash.xml` → `/product/etc/device_features/dash.xml`
     - Overlay 克隆 → `/product/overlay/MiuiFrameworkResOverlay.apk`
   - 原厂 43 项亮度/HBM/OLED 资源仍在克隆里。

## 目录

```
module/                 # 模块骨架（module.prop、脚本、META-INF）
scripts/build.sh        # 组装模块、签名、打包
scripts/patch_dash_xml.py
scripts/patch_overlay_apk.py
README.md
LICENSE
```

`input/`、`keys/`、`dist/`、`build/` 都在 `.gitignore` 里。

## 构建

依赖：

- Python 3.8+
- Android build-tools（`aapt2`、`zipalign`、`apksigner`）
- JDK/JRE（给 apksigner 用）
- `zip`

### 1. 从自己的手机取原始文件

```sh
mkdir -p input

# 本机 SSH 需要 -F 时自行加上（例如 ssh -F ~/.ssh/config phone）
ssh phone 'cat /product/etc/device_features/dash.xml' \
  > input/dash.xml
ssh phone 'cat /product/overlay/MiuiFrameworkResOverlay.apk' \
  > input/MiuiFrameworkResOverlay.apk
```

`input/` 不要提交；里面是小米固件文件。

### 2. 生成本地签名 key（不要提交）

```sh
mkdir -p keys
keytool -genkeypair \
  -keystore keys/qingshan4.p12 -storetype PKCS12 \
  -alias qingshan4 -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass qingshan4 -keypass qingshan4 \
  -dname "CN=Qingshan4"
```

### 3. 构建

```sh
BUILD_TOOLS="$ANDROID_HOME/build-tools/36.0.0" \
JAVA_HOME="/path/to/jdk" \
./scripts/build.sh \
  --dash input/dash.xml \
  --overlay input/MiuiFrameworkResOverlay.apk \
  --keystore keys/qingshan4.p12 \
  --ks-pass pass:qingshan4 \
  --key-pass pass:qingshan4 \
  --out dist/qingshan4-dash-v1.2.zip
```

构建脚本会：

1. patch `dash.xml` 的两个开关；
2. 把 Overlay 的版本值 3→4，去掉旧签名并重新签名；
3. 校验 Overlay 的包名、target、版本值；
4. 组装模块 zip。

## 安装

APatch Manager → 模块 → 从本地安装 zip → 重启。

或（已 root）：

```sh
apd module install /path/to/qingshan4-dash-v1.2.zip
reboot
```

## 验证

```sh
grep -n "enable_eyecare_wave_render\|support_night_wakeup_mode_setting" \
  /product/etc/device_features/dash.xml

cmd overlay list | grep android.miui.overlay
dumpsys overlay | grep -A10 "^android.miui.overlay:0"

# 打开设置里的护眼页后：
logcat -d | grep green_mountain_eyecare_version
# 期望：MiuiUtils: green_mountain_eyecare_version:4
```

## 卸载

APatch Manager 卸载模块 → 重启。

`uninstall.sh` 会 umount 两个 bind mount；重启后原厂
`MiuiFrameworkResOverlay.apk` 和 `dash.xml` 恢复。

## 注意

- 克隆使用本地 key 签名，和原厂 Xiaomi 证书不同；PMS 已接受并正常启用。
  以后 OTA 若更新了原厂 Overlay，需要按新的原厂 APK 重新构建。
- 仓库不包含、不分发任何小米 APK/XML/固件/日志；`input/` 与构建产物都在
  `.gitignore` 中。
- 这是针对 dash 的适配，不是通用青山护眼模块。
