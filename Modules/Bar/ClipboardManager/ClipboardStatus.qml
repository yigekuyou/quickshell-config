import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Config
import qs.Widget
import qs.Modules.Bar.common
import org.kde.kirigami as Kirigami

// 顶栏剪贴板入口。外观与 Network / Bluetooth / Volume 一致，统一来自 BarButton。
// 面板本体在 qs.Widget.ClipboardWidget（与 NetworkWidget 同目录），不放在这里。
BarButton {
    id: root

    property bool popupOpen: false
    checked: root.popupOpen

    icon: ClipboardService.currentKind === "image" ? "image-x-generic-symbolic" : "edit-paste-symbolic"
    iconSize: Math.round(Kirigami.Units.gridUnit * 0.8)

    // 最近一条内容的预览；无内容时 text 为空，标签整段隐藏，按钮自动收窄
    text: ClipboardService.count > 0 ? (ClipboardService.currentKind === "image" ? qsTr("图片") : ClipboardService.currentText.substring(0, 200).replace(/\s+/g, " ").trim()) : ""
    textMaxWidth: Kirigami.Units.gridUnit * 10

    onClicked: root.popupOpen = !root.popupOpen

    ClipboardWidget {
        id: popup
        anchorItem: root
        visible: root.popupOpen
        onCloseRequested: root.popupOpen = false
        onClosed: root.popupOpen = false
    }

    // IPC 控制面板（qs ipc call clip toggle / open / close）
    IpcHandler {
        target: "clip"

        function toggle() {
            root.popupOpen = !root.popupOpen;
        }

        function open() {
            root.popupOpen = true;
        }

        function close() {
            root.popupOpen = false;
        }
    }
}