import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

// 启动器窗口的管理者。
//
// 整个进程只创建一个 Launcher 实例，之后开关只切 visible：以前每次按快捷键都
// createObject 一个新窗口、关掉时 destroy()，既会闪一下，旧的 AppPage.qml 那套
// PopupWindow + mapToItem 还会不停抛 "Too many arguments" / "contentItem of null"。
Item {
    id: root

    property var launcherWindow: null
    readonly property bool isOpen: launcherWindow !== null && launcherWindow.visible

    function ensureWindow() {
        if (launcherWindow)
            return launcherWindow;

        const component = Qt.createComponent("Launcher.qml");
        if (component.status !== Component.Ready) {
            console.error("[launcher] 加载 Launcher.qml 失败: " + component.errorString());
            return null;
        }

        launcherWindow = component.createObject(root);
        if (!launcherWindow)
            console.error("[launcher] 创建启动器窗口失败");
        return launcherWindow;
    }

    function open() {
        const win = ensureWindow();
        if (win)
            win.openLauncher();
    }

    function close() {
        if (launcherWindow)
            launcherWindow.closeLauncher();
    }

    function toggle() {
        const win = ensureWindow();
        if (win)
            win.toggleLauncher();
    }

    IpcHandler {
        target: "launcher"

        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function toggle(): void {
            root.toggle();
        }
    }
}
