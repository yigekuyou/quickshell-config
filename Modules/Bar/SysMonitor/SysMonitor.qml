import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Modules.Bar.common
import org.kde.kirigami as Kirigami
Kirigami.AbstractCard {
    id: root

    // ================= 1. 样式与尺寸 =================

    property bool expanded: false
    property int barHeight: Sizes.barHeight

    // 动态宽度：展开显示全部，收起只显示 RAM
    implicitHeight: Sizes.barHeight
    padding: Sizes.secPad("right")   // 跟随「状态栏 → 右侧 → 内边距」
    background: Kirigami.ShadowedRectangle {
	    color: Kirigami.Theme.backgroundColor
	    opacity: 0.5
	    radius: Sizes.cornerRadius
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
	    command: ["cat", SysMonitorPath.cpuhwmon]
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
    property int gpuLoad: 0
    property int gpuPower: 0
    property int gpuFan: 0
    //GPU
    Process {
	    id: gpuProc
	    // 使用 stdbuf 确保输出不被内核缓存，实时流向 QML
		command: ["script", "/dev/null", "-qc", "amdgpu_fan watch_csv 1"]
    stderr: SplitParser {
		    onRead: data => console.log("GPU Error:", data)
	    }
	    stdout: SplitParser {
		    // 关键：将分隔符设置为换行符，这样每次 onRead 都是一行
		    onRead: data => {
			    if (!data || data.includes("Timestamp")) return
				    //console.log("GPU Raw Data:", data)
				    // 去掉前后空格并按逗号分割
				    var parts = data.trim().split(",")
				    if (parts.length >= 7) {
					    // 索引 4 是 Load (%), 索引 5 是 Power (Watts)
					    root.gpuLoad = parseInt(parts[4])
					    // 转换浮点数为整数
					    root.gpuPower = Math.round(parseFloat(parts[5]))
				    }
		    }
	    }
	    Component.onCompleted: running = true
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
    HoverHandler {
	    cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
	    acceptedButtons: Qt.LeftButton
	    onTapped: {
		    root.expanded = !root.expanded;
	    }
    }
    // ================= 5. 布局内容 =================
    // 每个指标 = 图标 + 可选进度环 + 可选数值。
    // 环（common/Ring.qml）用图标外圈表示百分比，受「状态栏 → 显示 → 图标圆环」控制；
    // 数值受「显示文字」控制，两者关掉后只剩图标。
    component Metric: RowLayout {
        id: metric
        property string icon: ""
        property color tint: Kirigami.Theme.textColor
        property real ratio: -1          // 0..1，<0 不画环
        property string text: ""

        spacing: Sizes.secGap("right")

        Item {
            // 环比图标大时按环的直径占位，免得四个指标之间的环互压
            implicitWidth: Sizes.barRing ? Math.max(Sizes.secIcon("right"), Sizes.ringSize(Sizes.secIcon("right")))
                                         : Sizes.secIcon("right")
            implicitHeight: Sizes.secIcon("right")

            Kirigami.Icon {
                anchors.centerIn: parent
                source: metric.icon
                implicitWidth: Sizes.secIcon("right")
                implicitHeight: Sizes.secIcon("right")
                color: metric.tint
            }

            Ring {
                anchors.centerIn: parent
                size: Sizes.ringSize(Sizes.secIcon("right"))
                lineWidth: Sizes.barRingWidth
                trackOpacity: Sizes.barRingTrackOpacity
                color: metric.tint
                progress: (Sizes.barRing && metric.ratio >= 0) ? Math.min(1, metric.ratio) : -1
            }
        }

        Label {
            visible: Sizes.barLabels && metric.text !== ""
            text: metric.text
            font.pixelSize: Math.round(Sizes.secIcon("right") * 0.95)
        }
    }

    contentItem: RowLayout {
        id: contentLayout
        spacing: Sizes.barSpacing
        layoutDirection: Qt.RightToLeft   // RAM 在最右

        Metric {
            icon: "memory"
            tint: Kirigami.Theme.positiveTextColor
            ratio: root.memUsage / 100
            text: root.memUsage + "%"
        }

        Metric {
            visible: root.expanded
            icon: "temp-symbolic"
            tint: getStatusColor(root.tempValue, 70, 85)
            ratio: root.tempValue / 100
            text: root.tempValue + "°C"
        }

        Metric {
            visible: root.expanded
            icon: "cpu"
            tint: getStatusColor(root.cpuValue, 70, 90)
            ratio: root.cpuValue / 100
            text: root.cpuValue + "%"
        }

        Metric {
            visible: root.expanded
            icon: "video-display"
            tint: getStatusColor(root.gpuLoad, 70, 90)
            ratio: root.gpuLoad / 100
            text: root.gpuLoad + "% | " + root.gpuPower + "W"
        }
    }
}
