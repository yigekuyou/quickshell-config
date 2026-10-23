import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 关于 / 配置文件位置。手改 json 后点「重新载入」即可生效（不用重启 qs）。
SettingsPage {
    id: root

    title: qsTr("关于")
    icon: "help-about"

    readonly property var entries: [
        {
            "label": qsTr("设置"),
            "path": Settings.path,
            "note": qsTr("全部可调参数的唯一来源")
        },
        {
            "label": "cava",
            "path": Directories.cavaConfigFile,
            "note": qsTr("顶栏频谱条（cava 自己读取）")
        },
        {
            "label": qsTr("配置目录"),
            "path": Directories.configDir,
            "note": qsTr("本 shell 的 QML 与资源")
        }
    ]

    // ================= 系统信息（fastfetch 风格）=================
    // QSysInfo 是纯 C++ 类、QML 不可见（qtdocs qsysinfo.html 只提供 C++ 接口），
    // 这里改用 Quickshell.Io 的 FileView 直读 /etc 与 /proc：效果等同、零命令
    // 依赖。系统信息基本静态，只有运行时间 / 内存用量会变，用 60s 的 Timer 刷。
    property string osName: ""
    property string kernelLine: ""
    property string hostName: ""
    property string uptimeText: ""
    property string cpuModel: ""
    property string memText: ""

    // Shell 自身的启动时间：Quickshell 单例原生提供（launchTime，QDateTime）
    readonly property string shellLaunchedText: Qt.formatDateTime(Quickshell.launchTime, "yyyy-MM-dd hh:mm")

    readonly property var sysRows: [
        { "label": qsTr("操作系统"), "prop": "osName" },
        { "label": qsTr("内核"), "prop": "kernelLine" },
        { "label": qsTr("主机"), "prop": "hostName" },
        { "label": qsTr("运行时间"), "prop": "uptimeText" },
        { "label": qsTr("处理器"), "prop": "cpuModel" },
        { "label": qsTr("内存"), "prop": "memText" },
        { "label": qsTr("Shell 启动"), "prop": "shellLaunchedText" }
    ]

    FileView {
        id: fvOsRelease
        path: "/etc/os-release"
        blockAllReads: true
    }
    FileView {
        id: fvKernel
        path: "/proc/sys/kernel/osrelease"
        blockAllReads: true
    }
    FileView {
        id: fvHostname
        path: "/etc/hostname"
        blockAllReads: true
    }
    FileView {
        id: fvUptime
        path: "/proc/uptime"
        blockAllReads: true
    }
    FileView {
        id: fvCpuinfo
        path: "/proc/cpuinfo"
        blockAllReads: true
    }
    FileView {
        id: fvMeminfo
        path: "/proc/meminfo"
        blockAllReads: true
    }

    function refreshSystemInfo(): void {
        // 操作系统：PRETTY_NAME 为主，VERSION_ID 没包含进去就补上
        fvOsRelease.reload()
        var osText = fvOsRelease.text()
        if (osText !== "") {
            var pretty = /PRETTY_NAME="([^"]*)"/.exec(osText)
            var verId = /VERSION_ID="?([^\n"]*)/.exec(osText)
            var name = pretty ? pretty[1] : ""
            if (verId && name.indexOf(verId[1]) < 0) name += " " + verId[1]
            if (name !== "") root.osName = name
        }

        // 内核
        fvKernel.reload()
        var kVer = fvKernel.text().trim()
        if (kVer !== "") root.kernelLine = "Linux " + kVer

        // 主机
        fvHostname.reload()
        var host = fvHostname.text().trim()
        if (host !== "") root.hostName = host

        // 运行时间：秒 → 天 / 小时 / 分
        fvUptime.reload()
        var secs = parseFloat(fvUptime.text().split(" ")[0]) || 0
        var d = Math.floor(secs / 86400)
        var h = Math.floor((secs % 86400) / 3600)
        var mi = Math.floor((secs % 3600) / 60)
        var upParts = []
        if (d > 0) upParts.push(d + qsTr(" 天"))
        if (h > 0 || d > 0) upParts.push(h + qsTr(" 小时"))
        upParts.push(mi + qsTr(" 分"))
        root.uptimeText = upParts.join(" ")

        // 处理器：型号 + 线程数（processor 行计数）
        fvCpuinfo.reload()
        var cpuText = fvCpuinfo.text()
        if (cpuText !== "") {
            var model = /model name\s*:\s*(.+)/.exec(cpuText)
            var threads = (cpuText.match(/^processor/gm) || []).length
            var name2 = model ? model[1].trim() : ""
            if (threads > 0) name2 += " (" + threads + qsTr(" 线程") + ")"
            if (name2 !== "") root.cpuModel = name2
        }

        // 内存：已用 / 总量（kB → GiB）
        fvMeminfo.reload()
        var memText2 = fvMeminfo.text()
        var memT = /MemTotal:\s+(\d+)/.exec(memText2)
        var memA = /MemAvailable:\s+(\d+)/.exec(memText2)
        if (memT) {
            var totalGiB = parseInt(memT[1]) / 1048576
            var usedGiB = memA ? (parseInt(memT[1]) - parseInt(memA[1])) / 1048576 : 0
            root.memText = usedGiB.toFixed(1) + " / " + totalGiB.toFixed(1) + " GiB"
        }
    }

    Component.onCompleted: root.refreshSystemInfo()

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.refreshSystemInfo()
    }

    SettingsGroup {

        title: qsTr("系统")

        Repeater {
            model: root.sysRows

            delegate: FormCard.AbstractFormDelegate {
                id: sysRow

                required property var modelData

                Layout.fillWidth: true
                background: null

                contentItem: RowLayout {
                    spacing: Kirigami.Units.mediumSpacing

                    Label {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                        text: sysRow.modelData.label
                        color: Kirigami.Theme.disabledTextColor
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root[sysRow.modelData.prop]
                        elide: Text.ElideRight
                        font.family: Sizes.fontFamilyMono
                        color: Kirigami.Theme.textColor
                    }
                }
            }
        }
    }

    SettingsGroup {

        title: qsTr("配置位置")

        Repeater {
            model: root.entries

            delegate: FormCard.AbstractFormDelegate {
                id: entryRow

                required property var modelData

                Layout.fillWidth: true
                background: null

                contentItem: RowLayout {
                    spacing: Kirigami.Units.mediumSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Label {
                            text: entryRow.modelData.label
                            font.weight: Font.DemiBold
                            color: Kirigami.Theme.textColor
                        }

                        Label {
                            Layout.fillWidth: true
                            text: entryRow.modelData.path
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            color: Kirigami.Theme.highlightColor
                        }

                        Label {
                            Layout.fillWidth: true
                            text: entryRow.modelData.note
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

                    ToolButton {
                        onClicked: Quickshell.execDetached(["xdg-open", entryRow.modelData.path])
                        contentItem: Kirigami.Icon {
                            source: "document-open"
                            color: Kirigami.Theme.textColor
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: implicitWidth
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {

        title: qsTr("维护")

        FormCard.AbstractFormDelegate {
            Layout.fillWidth: true
            background: null

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        text: Settings.ready ? qsTr("配置已载入") : qsTr("配置尚未载入")
                        font.weight: Font.DemiBold
                        color: Settings.ready ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                    }

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("手改 json 后重新载入即可生效；本窗口里的修改会自动保存。")
                        wrapMode: Text.WordWrap
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                Button {
                    text: qsTr("重新载入")
                    onClicked: Settings.reload()
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        text: qsTr("配置由 Services/Settings.qml 读写；设置窗口不占顶栏位置，")
            + qsTr("用 qs ipc call settings toggle 或全局快捷键 quickshell:settings 打开。")
        wrapMode: Text.WordWrap
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        color: Kirigami.Theme.disabledTextColor
    }
}