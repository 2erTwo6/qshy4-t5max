#!/system/bin/sh
umount /product/etc/device_features/dash.xml 2>/dev/null
umount /product/overlay/MiuiFrameworkResOverlay.apk 2>/dev/null
rm -rf /data/system/device_features_cache 2>/dev/null
rm -rf /data/system/display_features_cache 2>/dev/null
