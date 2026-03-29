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

	// --- 滑动的高亮块 ---
	Rectangle {
		id: indicator
		implicitHeight: Sizes.barHeight/2

		x: layout.x + (root.activeItem ? root.activeItem.x : 0)
		y: (root.activeItem ? root.activeItem.y : 0)

		width: root.activeItem ? root.activeItem.width : 0

		radius: Sizes.cornerRadius

		// 之前修改的高亮色
		color: Qt.alpha(Kirigami.Theme.activeTextColor,0.5)

		Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
		Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

		Behavior on color { ColorAnimation { duration: 200 } }
	}

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
				source:delegateRoot.active ? "notification-progress-active-symbolic"  : (ws ? "radio-checked-symbolic" : "radio-symbolic")
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
