#!/bin/sh
# clipboard-watch.sh — 后台剪贴板监听（wl-clipboard 的 data-control 协议）
# 无需窗口焦点，Hyprland / KWin / Sway 等 wlroots 系合成器通用。
#
# 用法：
#   clipboard-watch.sh          后台持续监听，每次剪贴板变化输出一帧
#   clipboard-watch.sh --once   输出当前剪贴板内容一次（启动时同步当前内容用）
#
# 帧格式：RS(0x1e) + 内容 + RS
# 收尾都加分隔符，让 quickshell 的 SplitParser 能立即切出完整帧；
# 连续两个 RS 产生的空帧由 QML 侧 addEntry 过滤。

emit='if wl-paste -l 2>/dev/null | grep -q "^text/"; then printf "\036"; wl-paste 2>/dev/null; printf "\036"; fi'

if [ "$1" = "--once" ]; then
	sh -c "$emit"
else
	exec wl-paste --watch sh -c "$emit"
fi
