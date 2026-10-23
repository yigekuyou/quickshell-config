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
	    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
	    border.width: 1
    }
    Behavior on implicitWidth {
	    NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutQuart }
    }
    // ================= 2. 数据源 =================
    // 全部改为 Quickshell.Io 的 FileView 直读 /proc 与 sysfs 伪文件，不再 fork
    // 任何外部命令（head / bash / free / cat / script / amdgpu_fan 全部退役——
    // 其中 amdgpu_fan 已从系统删除，旧版 GPU 数据源随之彻底失效）。
    // blockAllReads 让 reload() 同步完成、text() 立即返回新内容；这些都是
    // 内核伪文件、微秒量级读取，不会卡界面（FileView 文档对 block 的警告
    // 只针对大文件 / 慢存储场景）。

    property int lastCpuTotal: 0
    property int lastCpuIdle: 0
    property int memUsage: 0
    property int tempValue: 0
    property int cpuValue: 0
    property int diskValue: 0      // 新增硬盘数值(用于变色)
    property int gpuLoad: 0
    property int gpuPower: 0

    // CPU：/proc/stat 第一行，与旧版 `head -1 /proc/stat` 等价
    FileView {
        id: cpuStat
        path: "/proc/stat"
        blockAllReads: true
    }

    // 内存：/proc/meminfo（替代 `free`），按 MemAvailable 口径算已用百分比
    FileView {
        id: memInfo
        path: "/proc/meminfo"
        blockAllReads: true
    }

    // CPU 温度：hwmon 路径集中在 Config/SysMonitorPath.qml
    FileView {
        id: tempFile
        path: SysMonitorPath.cpuhwmon
        blockAllReads: true
    }

    // GPU：直读 amdgpu 驱动的 sysfs 节点（替代已删除的 amdgpu_fan watch_csv）
    //   gpu_busy_percent - 核心占用 0-100
    //   power1_input     - PPT 功耗，实测单位 mW（采样 24-39W 波动），除 1000 得 W
    FileView {
        id: gpuBusy
        path: SysMonitorPath.gpuBusy
        blockAllReads: true
    }
    FileView {
        id: gpuPower
        path: SysMonitorPath.gpuPower
        blockAllReads: true
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            // ---- CPU：两次采样之间的 idle / total 增量比 ----
            cpuStat.reload()
            var cpuLine = cpuStat.text().split("\n")[0]
            if (cpuLine.indexOf("cpu") === 0) {
                var p = cpuLine.trim().split(/\s+/)
                var idle = parseInt(p[4]) + parseInt(p[5])
                var total = 0
                for (var i = 1; i < p.length; i++) total += parseInt(p[i])
                if (lastCpuTotal > 0 && total > lastCpuTotal) {
                    root.cpuValue = Math.round(100 * (1 - (idle - lastCpuIdle) / (total - lastCpuTotal)))
                }
                lastCpuTotal = total
                lastCpuIdle = idle
            }

            // ---- 内存 ----
            memInfo.reload()
            var memText = memInfo.text()
            var memTotal = 0, memAvail = 0, mm
            mm = /MemTotal:\s+(\d+)/.exec(memText); if (mm) memTotal = parseInt(mm[1])
            mm = /MemAvailable:\s+(\d+)/.exec(memText); if (mm) memAvail = parseInt(mm[1])
            if (memTotal > 0) root.memUsage = Math.round(100 * (memTotal - memAvail) / memTotal)

            // ---- CPU 温度（hwmon 单位 m°C）----
            tempFile.reload()
            var rawTemp = parseInt(tempFile.text())
            if (!isNaN(rawTemp)) root.tempValue = Math.round(rawTemp / 1000)

            // ---- GPU ----
            gpuBusy.reload()
            var gpuBusyVal = parseInt(gpuBusy.text())
            if (!isNaN(gpuBusyVal)) root.gpuLoad = gpuBusyVal

            gpuPower.reload()
            var gpuPowerVal = parseInt(gpuPower.text())
            if (!isNaN(gpuPowerVal)) root.gpuPower = Math.round(gpuPowerVal / 1000)
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
