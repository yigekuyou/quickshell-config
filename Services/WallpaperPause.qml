pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Config
import qs.Services

// 壁纸自动暂停，对齐 WE 插件 config.qml 里的
//   PauseMode / PauseFilterByScreen / ScreenSaverPolicy / ResumeTime
//
// 只写 WallpaperPath.autoPaused（不落盘），渲染端读 WallpaperPath.suspended
// = paused || autoPaused，所以自动暂停和用户手动暂停互不覆盖。
Singleton {
    id: root

    // 锁屏状态。锁屏 UI 跑在独立进程里（Wallpaper/Lock.qml），
    // 主进程只知道“我发起了锁屏 / 收到解锁 IPC”，由 Load.qml 维护这个标志。
    property bool locked: false

    // Toplevel 的 activated/maximized/fullscreen 变化不会让列表失效，靠它触发重算
    property int revision: 0

    readonly property int mode: Settings.wallpaper.pauseMode

    // 0 焦点或最大化 / 1 焦点 / 2 最大化 / 3 全屏 / 4 任意窗口 / 5 从不
    function toplevelMatches(toplevel) {
        switch (root.mode) {
        case 0:
            return toplevel.activated || toplevel.maximized;
        case 1:
            return toplevel.activated;
        case 2:
            return toplevel.maximized;
        case 3:
            return toplevel.fullscreen;
        case 4:
            return !toplevel.minimized;
        default:
            return false;
        }
    }

    readonly property bool windowPause: {
        root.revision;

        if (root.mode === 5)
            return false;
        for (const toplevel of ToplevelManager.toplevels.values) {
            // 跳过弹出/子窗口，只看真正的顶层窗口
            if (!toplevel.parent && root.toplevelMatches(toplevel))
                return true;
        }
        return false;
    }

    // 0 继续运行 / 1 暂停
    readonly property bool lockPause: Settings.wallpaper.screenSaverPolicy === 1 && root.locked

    readonly property bool shouldPause: root.windowPause || root.lockPause

    // 解除暂停时按 ResumeTime 延迟恢复（插件里是“从暂停恢复前等多久”）
    Timer {
        id: resumeTimer

        interval: Math.max(1, Settings.wallpaper.resumeTime)
        repeat: false
        onTriggered: {
            if (!root.shouldPause)
                WallpaperPath.autoPaused = false;
        }
    }

    onShouldPauseChanged: {
        if (root.shouldPause) {
            resumeTimer.stop();
            WallpaperPath.autoPaused = true;
        } else {
            resumeTimer.restart();
        }
    }

    // 启动时可能已经在全屏/焦点窗口里
    Component.onCompleted: {
        if (root.shouldPause)
            WallpaperPath.autoPaused = true;
    }

    Instantiator {
        model: ToplevelManager.toplevels.values

        delegate: Connections {
            required property var modelData

            target: modelData

            function onActivatedChanged() {
                root.revision++;
            }
            function onMaximizedChanged() {
                root.revision++;
            }
            function onFullscreenChanged() {
                root.revision++;
            }
            function onMinimizedChanged() {
                root.revision++;
            }
            function onClosed() {
                root.revision++;
            }
        }

        onObjectAdded: root.revision++
        onObjectRemoved: root.revision++
    }

    IpcHandler {
        target: "pause"

        // qs ipc call pause state  -> autoPaused / window / lock
        function state(): string {
            return (WallpaperPath.autoPaused ? "1" : "0")
                + " window=" + (root.windowPause ? "1" : "0")
                + " lock=" + (root.lockPause ? "1" : "0")
                + " mode=" + root.mode;
        }
    }
}
