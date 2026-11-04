#!/system/bin/sh
MODDIR=${0%/*}

# dash.xml：把模块里的 dash.xml 绑到 /product，绕过 APatch 未挂载 system 文件的问题
SRC_XML="$MODDIR/system/product/etc/device_features/dash.xml"
if [ -f "$SRC_XML" ]; then
    mount --bind "$SRC_XML" /product/etc/device_features/dash.xml 2>/dev/null
fi

# 用“只把 green_mountain_eyecare_version 从 3 改成 4”的原厂 Overlay 克隆替换原厂文件
# 这样 Resources.getSystem()（MiuiUtils）读到的版本才是 4；原厂 43 项资源原样保留
SRC_OVL="$MODDIR/system/product/etc/qingshan4/MiuiFrameworkResOverlay_v4.apk"
if [ -f "$SRC_OVL" ]; then
    mount --bind "$SRC_OVL" /product/overlay/MiuiFrameworkResOverlay.apk 2>/dev/null
fi

# mi_ext 设备特性：打开 is_new_eye_care，锁屏护眼的色温才会沿用桌面状态。
# 否则 EffectScopeManagerV4 走旧逻辑，锁屏时把色温归零（锁屏冷、解锁暖）。
SRC_CUST="$MODDIR/system/mi_ext/product/etc/cust_features/device_features.xml"
if [ -f "$SRC_CUST" ]; then
    mount --bind "$SRC_CUST" /mi_ext/product/etc/cust_features/device_features.xml 2>/dev/null
fi
