import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import org.kde.kirigami as Kirigami
import qs.Config
import qs.Services

// 顶栏剪贴板入口。外观与 Network / Bluetooth 两个顶栏部件保持一致：
// ShadowedRectangle + Sizes.cornerRadius + 半透明背景 + 细描边。
Kirigami.ShadowedRectangle {
    id: root

    property bool popupOpen: false
    readonly property bool containsMouse: hoverHandler.hovered

    implicitWidth: layout.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: Sizes.barHeight
    color: Qt.alpha(Kirigami.Theme.backgroundColor, root.containsMouse || root.popupOpen ? 0.75 : 0.5)
    radius: Sizes.cornerRadius
    shadow.color: Qt.rgba(0, 0, 0, 0.2)
    shadow.size: 10
    shadow.yOffset: 2
    border.width: 1
    border.color: Qt.alpha(root.popupOpen ? Kirigami.Theme.highlightColor : Kirigami.Theme.dividerColor, 0.3)

    // --- 面板 ---
    ClipboardHistoryPopup {
        id: popup

        anchorItem: root
        visible: root.popupOpen
        onCloseRequested: root.popupOpen = false
        onClosed: root.popupOpen = false
    }

    // IPC 控制面板（qs ipc call clip toggle / open / close）
    IpcHandler {
        function toggle() {
            root.popupOpen = !root.popupOpen;
        }

        function open() {
            root.popupOpen = true;
        }

        function close() {
            root.popupOpen = false;
        }

        target: "clip"
    }

    // --- 交互区域 ---
    HoverHandler {
        id: hoverHandler

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.popupOpen = !root.popupOpen
    }

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            implicitWidth: Kirigami.Units.gridUnit * 0.8
            implicitHeight: Kirigami.Units.gridUnit * 0.8
            source: "edit-paste-symbolic"
            color: root.popupOpen ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
        }

        // 最近一条内容的预览；无内容时整段隐藏，部件自动收窄
        Label {
            visible: ClipboardService.currentText !== ""
            text: ClipboardService.currentText.replace(/\s+/g, " ").trim()
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.maximumWidth: Kirigami.Units.gridUnit * 10
            color: Kirigami.Theme.textColor
            opacity: 0.8
            font.pixelSize: Kirigami.Units.gridUnit * 0.8
        }

    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutQuart
        }

    }

}
