pragma Singleton

import QtQuick
import Quickshell
import qs.Services

// 空闲 / 锁屏 / 睡眠策略。数值全部来自 settings/settings.json 的 idle 段
// （在设置面板「空闲」页里改，改完立即生效，无需重启）。
Singleton {
    id: root

    readonly property bool idlelock: Settings.idle.lock
    readonly property bool idlebacklight: Settings.idle.backlight
    readonly property bool idledpms: Settings.idle.dpms
    readonly property bool idlesleep: Settings.idle.sleep

    // 单位：秒
    readonly property real idlelocktime: Settings.idle.lockTimeout
    readonly property real idlebacklighttime: Settings.idle.backlightTimeout
    readonly property real dpmsTimeout: Settings.idle.dpmsTimeout
    readonly property real sleepTimeout: Settings.idle.sleepTimeout
}