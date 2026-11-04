#!/usr/bin/env bash
# Build the Qingshan 4.0 dash module from files supplied by the user.
# The repository intentionally contains no Xiaomi APK/XML and no logs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${PYTHON:-python3}"
ZIP="${ZIP:-zip}"

usage() {
    cat <<'USAGE'
Usage:
  scripts/build.sh --dash <dash.xml> --overlay <MiuiFrameworkResOverlay.apk> \
      --cust-features <device_features.xml> \
      --keystore <keystore.p12> --ks-pass <pass:...> --key-pass <pass:...> \
      [--key-alias qingshan4] [--ks-type PKCS12] \
      [--build-tools <dir>] [--java-home <dir>] [--out <zip>]

Required:
  --dash           dash.xml pulled from the user's own phone
  --overlay        MiuiFrameworkResOverlay.apk pulled from the user's own phone
  --cust-features  /mi_ext/product/etc/cust_features/device_features.xml
                   pulled from the user's own phone
  --keystore       signing keystore (never commit it)
  --ks-pass        keystore password, e.g. pass:qingshan4
  --key-pass       key password, e.g. pass:qingshan4

Optional:
  --build-tools  Android build-tools directory (aapt2, zipalign, apksigner)
  --java-home    JDK/JRE home for apksigner
  --out          output zip (default: dist/qingshan4-dash-v1.3.zip)

Environment fallbacks:
  ANDROID_HOME / ANDROID_SDK_ROOT for build-tools; JAVA_HOME; PYTHON; ZIP.
USAGE
}

DASH_XML=""
OVERLAY_APK=""
CUST_XML=""
KEYSTORE=""
KS_PASS="${KS_PASS:-}"
KEY_PASS="${KEY_PASS:-}"
KEY_ALIAS="${KEY_ALIAS:-qingshan4}"
KS_TYPE="${KS_TYPE:-PKCS12}"
OUT="${OUT:-$ROOT/dist/qingshan4-dash-v1.3.zip}"
BUILD_TOOLS="${BUILD_TOOLS:-}"
JAVA_HOME="${JAVA_HOME:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --dash) DASH_XML="$2"; shift 2 ;;
        --overlay) OVERLAY_APK="$2"; shift 2 ;;
        --cust-features) CUST_XML="$2"; shift 2 ;;
        --keystore) KEYSTORE="$2"; shift 2 ;;
        --ks-pass) KS_PASS="$2"; shift 2 ;;
        --key-pass) KEY_PASS="$2"; shift 2 ;;
        --key-alias) KEY_ALIAS="$2"; shift 2 ;;
        --ks-type) KS_TYPE="$2"; shift 2 ;;
        --build-tools) BUILD_TOOLS="$2"; shift 2 ;;
        --java-home) JAVA_HOME="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

[ -n "$CUST_XML" ] || { echo "error: missing --cust-features" >&2; usage >&2; exit 2; }

for required in DASH_XML OVERLAY_APK KEYSTORE KS_PASS KEY_PASS; do
    if [ -z "${!required}" ]; then
        echo "error: missing --${required,,}" >&2
        usage >&2
        exit 2
    fi
done
[ -f "$DASH_XML" ] || { echo "error: dash.xml not found: $DASH_XML" >&2; exit 1; }
[ -f "$OVERLAY_APK" ] || { echo "error: overlay APK not found: $OVERLAY_APK" >&2; exit 1; }
[ -f "$CUST_XML" ] || { echo "error: cust device_features.xml not found: $CUST_XML" >&2; exit 1; }
[ -f "$KEYSTORE" ] || { echo "error: keystore not found: $KEYSTORE" >&2; exit 1; }

if [ -z "$BUILD_TOOLS" ]; then
    for base in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$HOME/Android/Sdk"; do
        if [ -n "$base" ] && [ -d "$base/build-tools" ]; then
            BUILD_TOOLS="$(find "$base/build-tools" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n 1)"
            break
        fi
    done
fi
if [ -z "$BUILD_TOOLS" ] || [ ! -x "$BUILD_TOOLS/aapt2" ]; then
    echo "error: Android build-tools with aapt2/zipalign/apksigner not found" >&2
    echo "       pass --build-tools <dir> or set ANDROID_HOME" >&2
    exit 1
fi
if [ -n "$JAVA_HOME" ]; then
    export PATH="$JAVA_HOME/bin:$PATH"
fi

for tool in "$PYTHON" "$ZIP" "$BUILD_TOOLS/aapt2" "$BUILD_TOOLS/zipalign" "$BUILD_TOOLS/apksigner"; do
    command -v "$tool" >/dev/null 2>&1 || { echo "error: missing tool: $tool" >&2; exit 1; }
done

mkdir -p "$(dirname "$OUT")"
OUT_DIR="$(cd "$(dirname "$OUT")" && pwd)"
OUT="$OUT_DIR/$(basename "$OUT")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> patching dash.xml"
"$PYTHON" "$ROOT/scripts/patch_dash_xml.py" "$DASH_XML" "$WORK/dash.xml"

echo "==> patching cust features (is_new_eye_care)"
"$PYTHON" "$ROOT/scripts/patch_cust_features_xml.py" "$CUST_XML" "$WORK/device_features.xml"
grep -q '<bool name="is_new_eye_care">true</bool>' "$WORK/device_features.xml" \
    || { echo "error: patched cust features do not enable is_new_eye_care" >&2; exit 1; }

echo "==> parsing overlay manifest"
"$BUILD_TOOLS/aapt2" dump xmltree --file AndroidManifest.xml "$OVERLAY_APK" > "$WORK/overlay-manifest.txt"
grep -q 'package="android.miui.overlay"' "$WORK/overlay-manifest.txt" \
    || { echo "error: overlay package is not android.miui.overlay" >&2; exit 1; }
grep -q 'targetPackage.*com\.miui\.rom' "$WORK/overlay-manifest.txt" \
    || { echo "error: overlay target is not com.miui.rom" >&2; exit 1; }

echo "==> patching overlay 3 -> 4"
"$PYTHON" "$ROOT/scripts/patch_overlay_apk.py" "$OVERLAY_APK" "$WORK/overlay-unsigned.apk"

echo "==> aligning and signing overlay"
"$BUILD_TOOLS/zipalign" -f 4 "$WORK/overlay-unsigned.apk" "$WORK/overlay-aligned.apk"
"$BUILD_TOOLS/apksigner" sign \
    --ks "$KEYSTORE" \
    --ks-type "$KS_TYPE" \
    --ks-key-alias "$KEY_ALIAS" \
    --ks-pass "$KS_PASS" \
    --key-pass "$KEY_PASS" \
    --min-sdk-version 26 \
    --out "$WORK/MiuiFrameworkResOverlay_v4.apk" \
    "$WORK/overlay-aligned.apk"
"$BUILD_TOOLS/apksigner" verify "$WORK/MiuiFrameworkResOverlay_v4.apk"

"$BUILD_TOOLS/aapt2" dump resources "$WORK/MiuiFrameworkResOverlay_v4.apk" > "$WORK/overlay-resources.txt"
if ! grep -A1 'integer/green_mountain_eyecare_version' "$WORK/overlay-resources.txt" | grep -q '4'; then
    echo "error: signed overlay does not contain version 4" >&2
    exit 1
fi

echo "==> assembling module zip"
STAGE="$WORK/stage"
cp -a "$ROOT/module" "$STAGE"
mkdir -p "$STAGE/system/product/etc/device_features" \
         "$STAGE/system/product/etc/qingshan4" \
         "$STAGE/system/mi_ext/product/etc/cust_features"
cp "$WORK/dash.xml" "$STAGE/system/product/etc/device_features/dash.xml"
cp "$WORK/MiuiFrameworkResOverlay_v4.apk" "$STAGE/system/product/etc/qingshan4/MiuiFrameworkResOverlay_v4.apk"
cp "$WORK/device_features.xml" "$STAGE/system/mi_ext/product/etc/cust_features/device_features.xml"
chmod 644 "$STAGE/system/product/etc/device_features/dash.xml" \
           "$STAGE/system/product/etc/qingshan4/MiuiFrameworkResOverlay_v4.apk" \
           "$STAGE/system/mi_ext/product/etc/cust_features/device_features.xml"
chmod 755 "$STAGE/customize.sh" "$STAGE/post-fs-data.sh" "$STAGE/uninstall.sh" \
          "$STAGE/META-INF/com/google/android/update-binary"

( cd "$STAGE" && "$ZIP" -q -r "$OUT" . )

echo "==> done"
ls -l "$OUT"
sha256sum "$OUT"
echo
echo "Install with APatch, then reboot."
