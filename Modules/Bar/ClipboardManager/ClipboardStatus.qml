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
    section: "left"

    property bool popupOpen: false
    checked: root.popupOpen

    // 只显示「正在复制的类型」，不显示内容：文本 / 图片 / 文件 / 其他
    readonly property string kind: ClipboardService.count > 0 ? ClipboardService.currentKind : ""
    readonly property string kindLabel: {
        switch (root.kind) {
        case "text": return qsTr("文本");
        case "image": return qsTr("图片");
        case "file": return qsTr("文件");
        case "": return "";
        default: return qsTr("其他");
        }
    }

    icon: root.kind === "image" ? "image-x-generic-symbolic"
        : (root.kind === "file" ? "text-x-generic" : "edit-paste-symbolic")
    iconSize: Sizes.secIcon(root.section)
    text: root.kindLabel

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