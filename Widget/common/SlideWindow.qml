import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Config
import org.kde.kirigami as Kirigami
import QtQuick.Controls
PopupWindow {
	id:popudroot
	anchor.window: barWindow
	anchor.edges: Edges.Top
	anchor.gravity: Edges.Bottom
	property var pos : mapToItem(parentWindow.contentItem, 0, parentWindow.height);
	anchor.rect.x: Math.round(pos.x)
	anchor.rect.y: Math.round(pos.y)
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
	implicitHeight:parent
	implicitWidth:parent
	color: Kirigami.Theme.backgroundColor
	radius: Kirigami.Units.gridUnit * 0.8
	border.width: 1
	border.color: Qt.alpha(Kirigami.Theme.focusColor, 0.3)
	shadow.color: Qt.rgba(0, 0, 0, 0.25)
	opacity: 1
	shadow.size: 15
	shadow.yOffset: 4
		Kirigami.ScrollablePage {
		anchors.fill: parent
		anchors.margins: Kirigami.Units.smallSpacing
		spacing: Kirigami.Units.mediumSpacing
		leftPadding: Kirigami.Units.smallSpacing
		rightPadding: Kirigami.Units.smallSpacing
		topPadding: Kirigami.Units.smallSpacing
		bottomPadding: Kirigami.Units.smallSpacing
		ColumnLayout {
			id: contentLayout
		}
		clip: true // 必须裁剪，否则滚动内容会超出底边圆角
		header: RowLayout{
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
			RowLayout { id: headerToolsLayout }
		}
        }
    }
}
