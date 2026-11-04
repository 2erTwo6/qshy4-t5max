#!/system/bin/sh
MODDIR=${0%/*}

ui_print "- 青山护眼4.0 dash 适配（Overlay 版本 4）"
ui_print "- 写入 dash.xml 与原厂 Overlay 的 v4 克隆"

set_perm_recursive "$MODDIR/system" 0 0 0755 0644 u:object_r:system_file:s0
for f in post-fs-data.sh uninstall.sh customize.sh; do
    [ -f "$MODDIR/$f" ] && set_perm "$MODDIR/$f" 0 0 0755 u:object_r:system_file:s0
done

rm -rf /data/system/device_features_cache 2>/dev/null
rm -rf /data/system/display_features_cache 2>/dev/null
killall feature_manager 2>/dev/null

ui_print "- 已完成，重启后生效"
