//ClipboardService.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Config

Singleton {
    id: root

    // ==================== 配置 ====================
    readonly property int maxHistory: 50
    readonly property string storePath: Quickshell.dataDir + "/quickshell-clipboard.json"
    readonly property string watchScript: Quickshell.env("HOME") + "/.config/quickshell/scripts/clipboard-watch.sh"

    // ==================== 对外数据 ====================
    property ListModel history: ListModel {}
    property string currentText: ""
    readonly property int count: history.count

    signal historyUpdated()

    // ==================== 后台监听 ====================
    // wl-paste --watch 基于 wlr/ext-data-control 协议，无需窗口焦点，
    // Hyprland、KWin 及其它 wlroots 合成器通用
    property real watchStartedAt: 0
    Process {
        id: watcher
        running: true
        command: ["/bin/sh", root.watchScript]
        stdout: SplitParser {
            splitMarker: "\u001e" // RS 记录分隔符，文本内含任意换行也不受影响
            onRead: frame => root.addEntry(frame)
        }
        onStarted: root.watchStartedAt = Date.now()
        onRunningChanged: {
            if (!watcher.running) {
                // 刚启动就退出（如合成器暂不可用）→ 退避后重连，避免死循环
                if (Date.now() - root.watchStartedAt < 2000)
                    watchRestartTimer.restart()
                else
                    watcher.running = true
            }
        }
    }
    Timer {
        id: watchRestartTimer
        interval: 1000
        onTriggered: watcher.running = true
    }

    // 启动时同步当前剪贴板内容（watch 只在变化时触发）
    Process {
        id: currentFetcher
        stdout: SplitParser {
            splitMarker: "\u001e"
            onRead: frame => root.addEntry(frame)
        }
    }

    // ==================== 写回剪贴板 ====================
    Process {
        id: copier
    }

    function copyToClipboard(text) {
        copier.exec(["wl-copy", text])
    }

    function clearHistory() {
        history.clear()
        currentText = ""
        root.historyUpdated()
        persistTimer.restart()
    }

    function removeEntry(text) {
        for (let i = history.count - 1; i >= 0; i--) {
            if (history.get(i).clipText === text)
                history.remove(i)
        }
        root.historyUpdated()
        persistTimer.restart()
    }

    // ==================== 条目管理 ====================
    function addEntry(text) {
        // 过滤空帧（相邻分隔符、空选择等）；统一去掉尾部换行免得产生幽灵条目
        const clean = text.replace(/\n+$/, "")
        if (clean.trim() === "")
            return
        // 去重：copyToClipboard 自身触发的事件也不会重复入库
        if (history.count > 0 && history.get(0).clipText === clean)
            return
        for (let i = history.count - 1; i >= 1; i--) {
            if (history.get(i).clipText === clean)
                history.remove(i)
        }
        history.insert(0, {
            "clipText": clean,
            "time": Date.now()
        })
        currentText = clean
        while (history.count > maxHistory)
            history.remove(history.count - 1)
        root.historyUpdated()
        persistTimer.restart()
    }

    // ==================== 持久化 ====================
    Timer {
        id: persistTimer
        interval: 500
        onTriggered: root.saveHistory()
    }
    Process {
        id: writer
    }

    function shquote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

    function saveHistory() {
        const items = []
        for (let i = 0; i < history.count; i++)
            items.push(history.get(i).clipText)
        const cmd = "mkdir -p " + shquote(Quickshell.dataDir) + " && printf %s " + shquote(JSON.stringify(items)) + " > " + shquote(root.storePath)
        writer.exec(["sh", "-c", cmd])
    }

    Process {
        id: loader
        stdout: StdioCollector {
            id: loaderCollector
            onStreamFinished: {
                const raw = loaderCollector.text
                if (!raw || raw.trim() === "")
                    return
                try {
                    const items = JSON.parse(raw)
                    if (!Array.isArray(items))
                        return
                    for (let i = 0; i < items.length; i++)
                        history.append({
                            "clipText": items[i],
                            "time": 0
                        })
                    if (history.count > 0)
                        currentText = history.get(0).clipText
                    root.historyUpdated()
                } catch (e) {
                    console.log("[ClipboardService] 历史文件解析失败: " + e)
                }
            }
        }
    }

    Component.onCompleted: {
        loader.exec(["sh", "-c", "cat " + shquote(root.storePath) + " 2>/dev/null || true"])
        currentFetcher.exec(["/bin/sh", root.watchScript, "--once"])
    }
}
