import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Config

Item {
    id: root

    // 截图：quickshell 原生 ScreencopyView（官方文档 Quickshell.Wayland）
    // captureSource 取 ShellScreen（Quickshell.screens[i]，需 wlr-screencopy，Hyprland 满足）
    // live:false 单帧 → grabToImage 出 QImage → 存 PNG → wl-copy(image/png) 写剪贴板。
    // 注：captureSource 必须在截图时赋值——加载时 QuickshellScreenInfo 的内部 screen
    // 指针未必就绪，且绑定不会因对象不变而重算，提早赋值会拿到空上下文。
    // grab 超时或失败时回退 grim 管道。

    readonly property string shotPath: "/tmp/quickshell-screenshot.png"
    property bool busy: false
    property int pendingIndex: 0

    Process {
        id: copier
    }

    function copyPngToClipboard() {
        copier.exec(["sh", "-c", "wl-copy --type image/png < " + root.shotPath])
    }

    function grimFallback() {
        copier.exec(["sh", "-c", "if command -v grim >/dev/null 2>&1; then grim - | wl-copy --type image/png; fi"])
    }

    // ===== IPC =====
    // quickshell ipc call shot shot          全屏→剪贴板（主屏）
    // quickshell ipc call shot screen 1      指定屏幕索引
    // quickshell ipc call shot area          区域选择（slurp，需 grim）
    IpcHandler {
        target: "shot"

        function shot(): void {
            root.startShot(0)
        }

        function screen(index: int): void {
            root.startShot(index)
        }

        function area(): void {
            copier.exec(["sh", "-c", "grim -g \"$(slurp)\" - | wl-copy --type image/png"])
        }
    }

    function startShot(index) {
        if (root.busy)
            return
        if (index < 0 || index >= Quickshell.screens.length) {
            console.warn("[screenshot] 屏幕索引越界: " + index)
            return
        }
        root.busy = true
        // 捕获窗口必须先可见并完成一次渲染，wayland 表面与 buffer 管理器就绪后
        // 再连 captureSource，否则首帧请求会打到未完成的上下文上
        root.pendingIndex = index
        shotWindow.visible = true
        armTimer.restart()
    }

    function doGrab() {
        // 看门狗不停：grab 回调可能永不触发（合成器渲染兼容问题），此时由
        // shotTimer 超时回退 grim
        shotTimer.restart()
        console.log("[screenshot] 开始抓帧 " + view.sourceSize.width + "x" + view.sourceSize.height)
        view.grabToImage(function (res) {
            shotTimer.stop()
            shotWindow.visible = false
            root.busy = false
            if (!res || !res.image) {
                console.warn("[screenshot] grabToImage 空图像，回退 grim")
                root.grimFallback()
                return
            }
            if (!res.saveToFile("file://" + root.shotPath)) {
                console.warn("[screenshot] 截图存盘失败，回退 grim")
                root.grimFallback()
                return
            }
            root.copyPngToClipboard()
        }, view.sourceSize)
    }

    // 窗口可见后延迟连接捕获源，等表面/渲染就绪
    Timer {
        id: armTimer
        interval: 400
        onTriggered: {
            if (!root.busy)
                return
            view.captureSource = Quickshell.screens[root.pendingIndex]
            if (view.hasContent && view.sourceSize.width > 0)
                root.doGrab()
            else
                view.captureFrame()
        }
    }

    // 取帧超时兜底（合成器不支持、grab 无响应等）
    Timer {
        id: shotTimer
        interval: 3000
        onTriggered: {
            if (root.busy) {
                shotWindow.visible = false
                root.busy = false
                console.warn("[screenshot] 取帧超时，回退 grim")
                root.grimFallback()
            }
        }
    }

    FloatingWindow {
        id: shotWindow
        visible: false
        implicitWidth: 320
        implicitHeight: 180
        color: "#22000000"

        ScreencopyView {
            id: view
            anchors.fill: parent
            live: false
            paintCursor: true

            onHasContentChanged: {
                console.log("[screenshot] hasContent=" + hasContent)
                if (hasContent && root.busy && view.sourceSize.width > 0)
                    root.doGrab()
            }
        }
    }
}
