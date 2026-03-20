import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config

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
    // --- 内部通用逻辑 ---
    QtObject {
        id: theme
        property color background: Colorscheme.background
        property color surface: Colorscheme.surface
        property color primary: Colorscheme.primary
        property color error: Colorscheme.error
        property color text: Colorscheme.on_background
        property color subtext: Colorscheme.tertiary
        property color outline: Colorscheme.outline
        property int radius: 16
        property int padding: 16
    }


    implicitWidth: 400
    implicitHeight: popudroot.windowHeight
    color: "transparent"
    Rectangle {
        id: bg
	anchors.fill: parent
	color: theme.background
        radius: theme.radius
        
        border.color: Qt.rgba(0,0,0,0.1)
        
        ColumnLayout {
		anchors.fill: parent
		anchors.margins: theme.padding
            spacing: 12
		Layout.fillWidth: true
		RowLayout {
			Layout.fillWidth: true
		    Text { text: popudroot.icon; font.family: "Font Awesome 6 Free Solid"; font.pixelSize: 20; color: theme.primary }
		    Text { text: popudroot.title; font.bold: true; font.pixelSize: 18; color: theme.text; Layout.fillWidth: true; Layout.leftMargin: 8 }
                RowLayout { id: headerToolsLayout }

            }

            ColumnLayout {
		    Layout.fillWidth: true
                id: contentLayout
            }
        }
    }
}
