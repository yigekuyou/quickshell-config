import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Config
import org.kde.kirigami as Kirigami
import QtQuick.Controls

PopupWindow {
	id:popudroot
	// 要锚定的栏内控件（由调用方传入，例如 anchorItem: root）。
	// 用 anchor.item 让 Quickshell 自己算位置；旧的 mapToItem + anchor.rect 写法
	// 会在每次重定位后重新求值，形成 pos <-> anchor.rect 的无限反馈，主线程 100% 卡死。
	// 未提供 anchorItem 时回退为“锚定本弹窗声明所在的窗口”（例如通知中心）。
	property Item anchorItem: null
	property var anchorWindow: null
	anchor.edges: Edges.Bottom
	anchor.gravity: Edges.Bottom
	anchor.margins.top: Kirigami.Units.smallSpacing

	property bool _updatingAnchor: false
	function updateAnchor() {
		if (_updatingAnchor)
			return;
		_updatingAnchor = true;
		const win = anchorWindow ? anchorWindow : parentWindow;
		if (anchorItem) {
			anchor.window = null;
			anchor.item = anchorItem;
		} else if (win) {
			anchor.item = null;
			anchor.window = win;
		}
		_updatingAnchor = false;
	}
	Component.onCompleted: Qt.callLater(updateAnchor)
	onAnchorItemChanged: Qt.callLater(updateAnchor)
	onAnchorWindowChanged: Qt.callLater(updateAnchor)
    // --- 开放给外部的属性 ---
    property string title: ""
    property string icon: ""
    property int windowHeight: 420
    property int extraTopMargin: 0
    property alias headerTools: headerToolsLayout.data
    default property alias content: contentLayout.data
	grabFocus: true
	implicitWidth: 400
	implicitHeight: popudroot.windowHeight
	color: "transparent"

    Kirigami.ShadowedRectangle {
        id: bg
		anchors.fill: parent
		color: Kirigami.Theme.backgroundColor
		radius: Kirigami.Units.gridUnit * 0.8
		border.width: 1
		border.color: Qt.alpha(Kirigami.Theme.focusColor, 0.3)
		shadow.color: Qt.rgba(0, 0, 0, 0.25)
		shadow.size: 15
		shadow.yOffset: 4

		Flickable {
			id: flick
			anchors.fill: parent
			anchors.margins: Kirigami.Units.smallSpacing
			clip: true
			// 宽度固定为视口宽度，避免内容宽度反向影响布局（ScrollablePage 在
			// 弹出窗口“显示后重新布局”时会因此进入无限重排，主线程 100% 卡死）
			contentWidth: width
			contentHeight: mainColumn.implicitHeight
			boundsBehavior: Flickable.StopAtBounds

			ColumnLayout {
				id: mainColumn
				width: flick.width
				spacing: Kirigami.Units.mediumSpacing

				RowLayout {
					id: headerToolsLayout
					Layout.fillWidth: true
					Kirigami.Icon {
						source: popudroot.icon
						implicitWidth: Kirigami.Units.gridUnit * 1.2
						implicitHeight: Kirigami.Units.gridUnit * 1.2
						color: Kirigami.Theme.activeTextColor
					}
					Kirigami.Heading {
						text: popudroot.title
						level: 4
						color: Kirigami.Theme.textColor
						Layout.fillWidth: true
					}
				}

				ColumnLayout {
					id: contentLayout
					Layout.fillWidth: true
					spacing: Kirigami.Units.mediumSpacing
				}
			}
		}
    }
}
