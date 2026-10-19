//ClipboardService.qml
//
// QML facade for the native clipboard manager.  The actual Wayland capture and
// history model live in the C++ singleton ClipboardManager (module
// com.github.yigekuyou.clipboard), which is not tied to the focus rules that
// make QClipboard useless for a background clipboard manager.
pragma Singleton
import QtQuick
import Quickshell
// 系统级安装的 QML 模块（RPM: qt6-qml-clipboard），走 Qt 默认 import path。
// 注意：相对目录 import "../ClipboardModule" 的方式在 quickshell 0.3.x 下不可行
// （qmlscanner 会报 unresolvable import / plugin not found），必须按 URI 导入。
import com.github.yigekuyou.clipboard

Singleton {
    id: root

    // ==================== 对外数据 ====================
    // QAbstractListModel；角色名与 delegate 的 required 属性一一对应。
    readonly property var history: ClipboardManager.history
    readonly property int count: ClipboardManager.count
    readonly property string currentText: ClipboardManager.currentText
    readonly property string currentKind: ClipboardManager.currentKind

    readonly property int maxHistory: ClipboardManager.maxHistory

    // 旧版模块（<= 20261019 的 RPM）用阻塞写把选区交给粘贴方：图片大于管道缓冲
    // （64 KiB，任意一张截图都超）时，读写两端在同一个事件循环里互等，整个 shell
    // 会卡死。修好的版本导出 asyncSend=true，调用方据此判断能不能放心发布大图。
    readonly property bool asyncSend: ClipboardManager.asyncSend === true

    signal historyUpdated()

    Connections {
        target: ClipboardManager

        function onHistoryUpdated() {
            root.historyUpdated();
        }
    }

    // ==================== 操作 ====================
    function copyToClipboard(text) {
        ClipboardManager.copyToClipboard(text);
    }

    function copyImage(path, mime) {
        ClipboardManager.copyImage(path, mime);
    }

    function removeEntry(uid) {
        ClipboardManager.removeEntry(uid);
    }

    function clearHistory() {
        ClipboardManager.clearHistory();
    }
}
