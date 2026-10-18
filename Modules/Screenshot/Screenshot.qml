import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Config

// 截图总控。每块屏幕一个 ScreenshotOverlay，同一时间只让其中一块（当前焦点屏）激活。
//
// IPC（Print 键 -> qs ipc call shot ui）：
//   qs ipc call shot ui      打开截图界面：框选后可选 复制 / 保存 / 全屏 / 取消
//   qs ipc call shot area    同上（兼容旧命令）
//   qs ipc call shot full    不显示界面，整屏截图直接进剪贴板
//   qs ipc call shot shot    同上（兼容旧命令）
//   qs ipc call shot screen 1  指定屏幕索引后整屏复制
//   qs ipc call shot close   关闭界面
Item {
    id: root

    property bool active: false
    property bool instant: false
    property int forcedIndex: -1

    readonly property string shotPath: "/tmp/quickshell-shot.png"

    // 当前焦点屏的名字（Hyprland 不可用时为空，退回第一块屏幕）
    readonly property string focusedScreenName: {
        try {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name)
                return Hyprland.focusedMonitor.name;
        } catch (e) {
            // 非 Hyprland 会话：忽略
        }
        return "";
    }

    function openUi(instantMode) {
        root.instant = instantMode;
        root.active = true;
    }

    function closeUi() {
        root.active = false;
    }

    // 这块屏幕是不是当前要用的那块
    function isTargetScreen(screenInfo) {
        if (root.forcedIndex >= 0)
            return screenInfo === Quickshell.screens[root.forcedIndex];
        if (root.focusedScreenName !== "")
            return screenInfo.name === root.focusedScreenName;
        return screenInfo === Quickshell.screens[0];
    }

    IpcHandler {
        target: "shot"

        function ui(): void {
            root.forcedIndex = -1;
            root.openUi(false);
        }

        function area(): void {
            root.forcedIndex = -1;
            root.openUi(false);
        }

        function full(): void {
            root.forcedIndex = -1;
            root.openUi(true);
        }

        function shot(): void {
            root.forcedIndex = -1;
            root.openUi(true);
        }

        function screen(index: int): void {
            if (index < 0 || index >= Quickshell.screens.length) {
                console.warn("[screenshot] 屏幕索引越界: " + index);
                return;
            }
            root.forcedIndex = index;
            root.openUi(true);
        }

        function close(): void {
            root.closeUi();
        }

    }

    Variants {
        model: Quickshell.screens

        ScreenshotOverlay {
            screen: modelData
            active: root.active && root.isTargetScreen(modelData)
            instant: root.instant
            shotPath: root.shotPath

            onFinished: root.closeUi()
            onFailed: {
                console.warn("[screenshot] 取帧失败");
                root.closeUi();
            }
        }
    }
}
