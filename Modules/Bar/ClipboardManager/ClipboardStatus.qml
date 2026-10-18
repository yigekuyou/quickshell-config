import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Services
import qs.Config
import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: root
    implicitHeight: Sizes.barHeight
    property bool popupOpen: false
    headerOrientation: Qt.Horizontal
    padding: Kirigami.Units.smallSpacing
    background: Kirigami.ShadowedRectangle {
        color: Kirigami.Theme.backgroundColor
        opacity: 0.5
        radius: Kirigami.Units.smallSpacing
        border.color: Kirigami.Theme.focusColor
        border.width: activeFocus ? 1 : 0
    }
    Behavior on implicitWidth {
        NumberAnimation {
            duration: Kirigami.Units.longDuration
            easing.type: Easing.OutQuart
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.popupOpen = !root.popupOpen
    }

    contentItem: RowLayout {
        id: layout
        layoutDirection: Qt.RightToLeft
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        Kirigami.Icon {
            source: "clipman-symbolic"
            color: Kirigami.Theme.activeTextColor
            implicitHeight: Kirigami.Units.iconSizes.small
            implicitWidth: implicitHeight
        }
        Kirigami.Heading {
            level: 5
            opacity: 0.7
            visible: ClipboardService.currentText !== ""
            text: ClipboardService.currentText.replace(/\n/g, " ").substring(0, 18)
            elide: Text.ElideRight
            Layout.maximumWidth: Kirigami.Units.gridUnit * 10
        }
    }

    ClipboardHistoryPopup {
        visible: root.popupOpen
        onCloseRequested: root.popupOpen = false
    }
}
