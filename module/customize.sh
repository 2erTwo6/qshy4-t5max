#!/system/bin/sh
# customize.sh 是被安装器 source 的，$0 不是本文件；优先用安装器提供的 MODPATH。
MODDIR="${MODPATH:-${0%/*}}"

ui_print "- 青山护眼4.0 dash 适配（Overlay 版本 4 + 新护眼作用域）"
ui_print "- 写入 dash.xml、Overlay v4 克隆与 mi_ext 设备特性"

set_perm_recursive "$MODDIR/system" 0 0 0755 0644 u:object_r:system_file:s0
for f in post-fs-data.sh uninstall.sh customize.sh; do
    [ -f "$MODDIR/$f" ] && set_perm "$MODDIR/$f" 0 0 0755 u:object_r:system_file:s0
done

rm -rf /data/system/device_features_cache 2>/dev/null
rm -rf /data/system/display_features_cache 2>/dev/null
killall feature_manager 2>/dev/null

ui_print "- 已完成，重启后生效"
