import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config
import org.kde.kirigami as Kirigami
Kirigami.AbstractCard {
    id: root

    // ================= 1. 样式与尺寸 =================

    property bool expanded: false
    property int barHeight: Sizes.barHeight

    // 动态宽度：展开显示全部，收起只显示 RAM
    implicitWidth: expanded ? contentLayout.implicitWidth + Kirigami.Units.largeSpacing * 2
    : ramGroup.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: Kirigami.Units.gridUnit * 2
    padding: Kirigami.Units.smallSpacing
    background: Rectangle {
	    color: Kirigami.Theme.backgroundColor
	    opacity: 0.5
	    radius: Kirigami.Units.smallSpacing
	    border.color: Kirigami.Theme.focusColor
	    border.width: root.activeFocus ? 1 : 0
    }
    Behavior on implicitWidth {
	    NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutQuart }
    }
    // ================= 2. 数据源 =================

    property int lastCpuTotal :0
    property int lastCpuIdle: 0
    property int memUsage: 0
    property int tempValue: 0
    property int cpuValue: 0
    property int diskValue: 0      // 新增硬盘数值(用于变色)
    Process {
	    id: cpuProc
	    command: ["head", "-1", "/proc/stat"]
	    stdout: SplitParser {
		    onRead: data => {
			    if (!data) return
				    var p = data.trim().split(/\s+/)
				    var idle = parseInt(p[4]) + parseInt(p[5])
				    var total = p.slice(1, 8).reduce((a, b) => a + parseInt(b), 0)
				    if (lastCpuTotal > 0) {
					    root.cpuValue = Math.round(100 * (1 - (idle - lastCpuIdle) / (total - lastCpuTotal)))
				    }
				    lastCpuTotal = total
				    lastCpuIdle = idle
		    }
	    }
	    Component.onCompleted: running = true
    }
    // Memory process
    Process {
	    id: memProc
	    command: ["bash", "-c", "free | grep Mem"]
	    environment: ({
		    "LANG": "C",
	    })

	    stdout: SplitParser {
		    onRead: data => {
			    if (!data) return
				    var parts = data.trim().split(/\s+/)
				    var total = parseInt(parts[1]) || 1
				    var used = parseInt(parts[2]) || 0
				    memUsage = Math.round(100 * used / total)
		    }
	    }
	    Component.onCompleted: running = true
    }
    Process {
	    id: tempProc
	    // thermal_zone0 通常是 CPU 核心温度，单位是毫摄氏度 (m°C)
	    command: ["cat", "/sys/class/thermal/thermal_zone0/temp"]
	    stdout: SplitParser {
		    onRead: data => {
			    if (!data) return
				    var rawTemp = parseInt(data.trim())
				    if (!isNaN(rawTemp)) {
					    root.tempValue = Math.round(rawTemp / 1000) // 转换为摄氏度
				    }
		    }
	    }
    }
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
		cpuProc.running = true
		memProc.running = true
		tempProc.running=true
	}
    }

    // ================= 3. 颜色逻辑 =================
    function getStatusColor(val, warn, crit) {
	    if (val > crit) return Kirigami.Theme.negativeTextColor;
	    if (val > warn) return Kirigami.Theme.neutralTextColor;
	    return Kirigami.Theme.textColor;
    }

    // ================= 4. 交互区域 =================
    ToolTip.visible: mouseArea.containsMouse
    ToolTip.text: expanded ? "Click to collapse" : "Click to expand details"
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.expanded = !root.expanded;
        }
    }

    // ================= 5. 布局内容 =================
    contentItem: RowLayout {
        id: contentLayout
        spacing: Kirigami.Units.largeSpacing  // 收起时去掉间距
        // 从右向左排：RAM 在最右边
        layoutDirection: Qt.RightToLeft

        // ---  RAM (常驻) ---
        RowLayout {
            id: ramGroup
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
		    source: "memory"
		    implicitWidth: Kirigami.Units.iconSizes.small
		    implicitHeight: Kirigami.Units.iconSizes.small
		    color: Kirigami.Theme.positiveTextColor
	    }
	    Label {
		    text: root.memUsage +"%"
	    }
        }


        // ---  Temp (展开显示) ---
        RowLayout {
		visible: root.expanded //
		spacing: Kirigami.Units.smallSpacing
		Kirigami.Icon {
			source: "temp-symbolic"
			implicitWidth: Kirigami.Units.iconSizes.small
			implicitHeight: Kirigami.Units.iconSizes.small
			color: getStatusColor(root.tempValue, 70, 85)
		}
		Label { text: root.tempValue + "°C" }
	}

        // --- CPU (展开显示) ---
        RowLayout {
		visible: root.expanded //
		spacing: Kirigami.Units.smallSpacing
		Kirigami.Icon {
			source: "cpu"
			implicitWidth: Kirigami.Units.iconSizes.small
			implicitHeight: Kirigami.Units.iconSizes.small
			color: getStatusColor(root.cpuValue, 70, 90)
		}
		Label { text: root.cpuValue + "%" }
	}
    }
}
