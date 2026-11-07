import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import org.kde.kirigami as Kirigami

// 系统信息 —— 头像 + 主机信息。
// 视觉语言与 ClockContent / MediaContent 统一：
// Kirigami.Heading/Label 排版、Kirigami.Theme 配色、Kirigami.Units 尺寸。
Item {
    id: root

    // ================== 极致轻量的数据获取逻辑 ==================
    // 1. 环境变量直读 (绝对零开销)
    property string sysUser: Quickshell.env("USER") || "archirithm"
    property string sysWm: (Quickshell.env("XDG_SESSION_DESKTOP") || "niri").toLowerCase()

    // 2. 硬件与主机名缓存
    property string sysHost: "archlinux"
    property string sysChassis: "Computer"

    // 3. 原生 sh + cat 读取内存虚拟文件系统 (耗时 < 1ms，无 I/O 负担)
    Process {
        id: fetchProc
        command: ["sh", "-c", "echo \"{\\\"host\\\": \\\"$(cat /etc/hostname 2>/dev/null)\\\", \\\"vendor\\\": \\\"$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)\\\", \\\"chassis\\\": \\\"$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)\\\"}\""]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    const json = JSON.parse(data);
                    if (json.host && json.host.trim() !== "") root.sysHost = json.host.trim();

                    // 清理厂商名称中冗余的后缀 (例如 "HP Inc." 变成 "HP")
                    const vendor = json.vendor ? json.vendor.trim().replace(" Inc.", "").replace(" Corporation", "") : "Unknown";

                    // 解析 Linux Chassis 代码
                    const type = parseInt(json.chassis);
                    let typeStr = "Computer";
                    if ([3, 4, 6, 7].includes(type)) typeStr = "Desktop";
                    else if ([8, 9, 10, 11, 31, 32].includes(type)) typeStr = "Notebook";

                    // 组合成 "Notebook HP" 的格式
                    root.sysChassis = typeStr + (vendor !== "Unknown" ? (" " + vendor) : "");
                } catch(e) { console.log("Fetch JSON error: " + e); }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // ==========================================
        // 1. 头像区域 (顶部，正圆，MediaContent 封面同款容器)
        // ==========================================
        Kirigami.ShadowedRectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.preferredWidth: Kirigami.Units.gridUnit * 6
            Layout.preferredHeight: Kirigami.Units.gridUnit * 6
            radius: Kirigami.Units.gridUnit * 3
            color: Kirigami.Theme.backgroundColor
            // 与 DynamicIsland 外框同款的细腻描边
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)

            Kirigami.ShadowedImage {
                id: avatarImg
                anchors.fill: parent
                source: "file:///var/lib/AccountsService/icons/" + Quickshell.env("USER")
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            // 没有头像时显示的图标
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Kirigami.Units.iconSizes.medium
                height: Kirigami.Units.iconSizes.medium
                source: "user-identity"
                visible: avatarImg.status !== Image.Ready
            }
        }

        // 占位：把信息推到底部
        Item {
            Layout.fillHeight: true
        }

        // ==========================================
        // 2. 底部 Fetch 信息 (规整的三行排布)
        // ==========================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                Layout.fillWidth: true
                text: root.sysUser + " @ " + root.sysHost
                level: 4
                elide: Text.ElideRight
                horizontalAlignment: Qt.AlignHCenter
            }
            Kirigami.Heading {
                Layout.fillWidth: true
                text: "Chassis : " + root.sysChassis
                level: 5
                opacity: 0.7
                elide: Text.ElideRight
                horizontalAlignment: Qt.AlignHCenter
            }
            Kirigami.Heading {
                Layout.fillWidth: true
                text: "WM : " + root.sysWm
                level: 5
                opacity: 0.7
                elide: Text.ElideRight
                horizontalAlignment: Qt.AlignHCenter
            }
        }
    }
}
