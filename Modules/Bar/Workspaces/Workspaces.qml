import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import qs.Services
import qs.Config
import org.kde.kirigami as Kirigami
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
				id:delegateRoot
				property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
				property bool active : Hyprland.focusedWorkspace?.id === (index + 1)
				implicitWidth: active ? (numText.implicitWidth + 24) : (numText.implicitWidth + 12)

				onActiveChanged: { if (active) root.activeItem = delegateRoot }
				Component.onCompleted: { if (active) root.activeItem = delegateRoot }

				Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

			Kirigami.Icon {
				id:numText
				anchors.centerIn:parent
				implicitHeight:Kirigami.Units.iconSizes.small
				implicitWidth:implicitHeight
				source:delegateRoot.active ? "notification-progress-active-symbolic"  : (ws ? "notification-progress-inactive-symbolic" : "notification-progress-inactive-symbolic")
				color: delegateRoot.active ? Kirigami.Theme.highlightColor  : (ws ? Kirigami.Theme.activeTextColor : Kirigami.Theme.textColor)

				Behavior on color { ColorAnimation { duration: 200 }
				}
				TapHandler {
					onTapped: Hyprland.dispatch("workspace " + (index + 1))
				}
				}

			}
		}
	}
}
