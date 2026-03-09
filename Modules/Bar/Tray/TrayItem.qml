import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets // 包含 PopupWindow
import qs.config

MouseArea {
	id: root
	required property var modelData

	implicitWidth: 24
	implicitHeight: 24
	hoverEnabled: true
	cursorShape: Qt.PointingHandCursor
	acceptedButtons: Qt.LeftButton | Qt.RightButton

	// --- 状态控制 ---
	// 使用 PopupWindow 后，通常它会自动处理点击外部关闭，但我们保留手动控制

	onClicked: (event) => {
		if (event.button === Qt.LeftButton) {
			modelData.activate();
			popup.visible = false;
		} else if (event.button === Qt.RightButton) {
			// 切换窗口显示状态
			modelData.secondaryActivate();
			popup.visible = !popup.visible;
		}
	}

	Image {
		id: content
		anchors.fill: parent
		anchors.margins: 2
		source: root.modelData.icon.includes("spotify") ? "image://icon/spotify" : root.modelData.icon
		fillMode: Image.PreserveAspectFit
	}
}
