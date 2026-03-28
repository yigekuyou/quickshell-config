import QtQuick
import Quickshell
import qs.Config
import Quickshell.Io

Rectangle {
    id: root

    // --- 样式设定 (完全仿照 PowerButton) ---
    color: Colorscheme.on_primary_container 
    
    radius: Sizes.cornerRadius
    implicitHeight: Sizes.barHeight
    
    // 宽度自适应
    implicitWidth: icon.contentWidth + 20

    // --- 交互区域 ---
    Process {
	    id: notif
	    running: false
	    command: ["qs", "--path", Quickshell.env("XDG_CONFIG_HOME") + "/quickshell/Wallpaper/Notif.qml", "ipc", "call", "notif", "open"]
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        
        // 3. 点击切换开关
        onClicked: {
            notif.startDetached();
        }
    }

    // --- 图标内容 ---
    Text {
        id: icon
        anchors.centerIn: parent
        
        // 铃铛图标 (Font Awesome)
        text: "\uf0f3" 
        font.family: "Font Awesome 6 Free Solid"
        font.bold: true
        
    }
}
