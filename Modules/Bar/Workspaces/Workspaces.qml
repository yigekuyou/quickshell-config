import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Config
import org.kde.kirigami as Kirigami
import Quickshell.WindowManager

Kirigami.ShadowedRectangle {
    id: root
    color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.5)

    radius: Sizes.cornerRadius
    implicitHeight: Kirigami.Units.iconSizes.small
    implicitWidth: layout.width + 20

    property Item activeItem: null

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 5

        Repeater {
            model: 10
            delegate: Kirigami.ShadowedRectangle {
                id: delegateRoot
                property var ws: WindowManager.windowsets.find(w => w.coordinates.includes(index + 1))
                property bool active: ws ? ws.active : false
                implicitWidth: active ? (numText.implicitWidth + 24) : (numText.implicitWidth + 12)

                onActiveChanged: {
                    if (active)
                        root.activeItem = delegateRoot;
                }
                Component.onCompleted: {
                    if (active)
                        root.activeItem = delegateRoot;
                }

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuad
                    }
                }

                Kirigami.Icon {
                    id: numText
                    anchors.centerIn: parent
                    implicitHeight: Kirigami.Units.iconSizes.small
                    implicitWidth: implicitHeight
                    source: ws ? (ws.active ? "notification-progress-active-symbolic" :"notification-progress-inactive-symbolic") : "notification-progress-inactive-symbolic"
                    color: ws ? (ws.active ? Kirigami.Theme.highlightColor: Kirigami.Theme.activeTextColor ): Kirigami.Theme.textColor
		    Kirigami.Heading {
			    anchors.centerIn: parent // 基线对齐
			    text: ws?index+1: ""
			    level: 4
			    color: Kirigami.Theme.disabledTextColor
		    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 200
                        }
                    }
                    TapHandler {
                        onTapped: {
                            if (ws && ws.canActivate) {
                                ws.activate();
                            }
                        }
                    }
                }
            }
        }
    }
}
