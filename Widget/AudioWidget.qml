pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Config
import qs.Services
import qs.Widget.common
import qs.Widget.audio
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

SlideWindow {
    id: root
    title: qsTr("混音器")
    icon: {
        if (Volume.sinkVolume === 0 || Volume.sinkMuted)
            return "audio-volume-muted";
        if (Volume.sinkVolume < 0.33)
            return "audio-volume-low";
        if (Volume.sinkVolume < 0.66)
            return "audio-volume-medium";
        return "audio-volume-high";
    }

    // 高度贴着内容走（与 ClipboardWidget / NotificationWidget 同模式）：
    // 应用少时不留一大片空白，应用多了封顶后由列表内部的 Flickable 滚动。
    windowHeight: Math.round(Math.max(300, Math.min(480, contentHeight + Kirigami.Units.largeSpacing)))

    // 应用列表封顶高度：按当前委托的实际行高折算（appsColumn 高度 ÷ 委托数），
    // 最多完整展示约 2.x 个应用委托——从第 3 个应用起列表内部滚动并出现滚动条。
    // 不用固定的 gridUnit 倍数：换字体/主题时行高会变，按行高折算在任何尺寸下都精确。
    readonly property real appRowHeight: appTracker.linkGroups.length > 0
        ? appsColumn.implicitHeight / appTracker.linkGroups.length
        : 0
    readonly property real maxAppsHeight: Math.max(root.appRowHeight * 2.4, Kirigami.Units.gridUnit * 3)

    // --- Pipewire 逻辑 ---
    property var defaultSink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.defaultSink] }
    PwNodeLinkTracker { id: appTracker; node: root.defaultSink }

    function isHeadphone(node) {
        if (!node)
            return false;
        const icon = node.properties ? (node.properties["device.icon-name"] || "") : "";
        const desc = node.description || "";
        return icon.includes("headphone") || desc.toLowerCase().includes("headphone") || desc.includes("耳机");
    }

    function nodeMuted(node) {
        return !!(node && node.audio && node.audio.muted);
    }

    function nodeVolume(node) {
        return (node && node.audio) ? node.audio.volume : 0.0;
    }

    function appLabel(node) {
        if (!node)
            return "";
        const app = (node.properties && node.properties["application.name"]) || node.description || node.name;
        const media = node.properties ? node.properties["media.name"] : undefined;
        return media ? `${app} - ${media}` : app;
    }

    // --- 标题栏工具：音频设置 + 总静音开关 ---
    headerTools: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        ToolButton {
            id: settingsButton
            action: Kirigami.Action {
                id: settingsAction
                icon.name: "audio-card"
                text: qsTr("音频设置")
                onTriggered: Quickshell.execDetached(["systemsettings", "kcm_pulseaudio"])
            }
            flat: true
            display: AbstractButton.IconOnly
            ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
            ToolTip.visible: hovered
            ToolTip.text: settingsAction.text
            contentItem: Kirigami.Icon {
                source: settingsAction.icon.name
                color: settingsButton.hovered ? Kirigami.Theme.hoverColor : Kirigami.Theme.textColor
            }
        }

        Kirigami.Separator {
            Layout.fillHeight: true
        }

        Switch {
            id: outputMuteSwitch
            checked: root.nodeMuted(root.defaultSink)
            onToggled: {
                if (root.defaultSink && root.defaultSink.audio)
                    root.defaultSink.audio.muted = checked;
            }
            ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
            ToolTip.visible: hovered
            ToolTip.text: checked ? qsTr("输出设备 已静音") : qsTr("输出设备 未静音")
        }
    }

    // --- 1. 输出设备 ---
    // 与 BluetoothWidget 相同：列表项用 FormCard + AbstractFormDelegate 保持 KDE 外观，
    // 不使用 FormButtonDelegate（它内部的换行 Label 会在弹窗首次显示时触发布局死循环）。
    FormCard.FormCard {
        id: sinkCard
        Layout.fillWidth: true
        property var sink: root.defaultSink

        FormCard.AbstractFormDelegate {
            id: sinkRow
            Layout.fillWidth: true

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: root.isHeadphone(sinkCard.sink) ? "audio-headphones" : "audio-speakers"
                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                    implicitHeight: implicitWidth
                    color: root.nodeMuted(sinkCard.sink) ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.linkColor
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        Layout.fillWidth: true
                        text: sinkCard.sink ? (sinkCard.sink.description || sinkCard.sink.name) : qsTr("未找到输出设备")
                        elide: Text.ElideRight
                        font.bold: true
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.nodeMuted(sinkCard.sink) ? qsTr("已静音") : qsTr("默认输出设备")
                        elide: Text.ElideRight
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                Label {
                    text: Math.round(root.nodeVolume(sinkCard.sink) * 100) + "%"
                    font.bold: true
                    color: root.nodeMuted(sinkCard.sink) ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.highlightColor
                }
            }
        }

        // 主音量条：沿用 VolumeSlider，左右留出与 delegate 文本对齐的边距
        VolumeSlider {
            Layout.leftMargin: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
            node: sinkCard.sink
            isHeadphone: root.isHeadphone(sinkCard.sink)
        }
    }

    // --- 2. 应用程序 ---
    // 小节标题固定不随列表滚动，右侧用小字显示当前正在播放的应用数
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing
        visible: appTracker.linkGroups.length > 0

        Kirigami.Heading {
            text: qsTr("应用程序")
            level: 4
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Label {
            text: appTracker.linkGroups.length
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: Kirigami.Units.smallSpacing
        }
    }

    // 应用列表：委托数量少时贴着内容走；内容超过 maxAppsHeight 后封顶，
    // 由内部滚动条接管（与 ClipboardWidget 的列表同模式）。
    Flickable {
        id: appScroll

        Layout.fillWidth: true
        // 内容少时让 Flickable 收缩，多时封顶，超过时由内部滚动条接管
        Layout.preferredHeight: Math.min(contentHeight, root.maxAppsHeight)
        visible: appTracker.linkGroups.length > 0
        contentWidth: width
        contentHeight: appsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        // 细滚动条：仅当内容比视口高时出现；手柄宽度固定，不抢占内容宽度
        ScrollBar.vertical: ScrollBar {
            id: appScrollBar

            policy: appScroll.contentHeight > appScroll.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            interactive: true
            implicitWidth: Kirigami.Units.smallSpacing + 6
            padding: 3
            z: 100
            onPressedChanged: {
                if (!pressed && size < 1)
                    appScroll.returnToBounds();
            }

            contentItem: Rectangle {
                implicitWidth: 5
                // 手柄长度按可见比例走（size = 可见高度 / 总高度），太短时保底两个网格
                implicitHeight: Math.min(appScrollBar.available, Math.max(Kirigami.Units.gridUnit * 2, appScrollBar.size * appScrollBar.available))
                radius: implicitWidth / 2
                color: Qt.alpha(Kirigami.Theme.textColor, appScrollBar.pressed ? 0.6 : appScrollBar.hovered ? 0.42 : 0.25)

                Behavior on color {
                    ColorAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
            }

            background: Rectangle {
                radius: 4
                color: Qt.alpha(Kirigami.Theme.backgroundColor, appScrollBar.pressed ? 0.35 : 0)

                Behavior on color {
                    ColorAnimation {
                        duration: Kirigami.Units.shortDuration
                    }
                }
            }
        }

        ColumnLayout {
            id: appsColumn

            width: appScroll.width
            spacing: Kirigami.Units.mediumSpacing

            Repeater {
                model: appTracker.linkGroups

                FormCard.FormCard {
                    id: appCard
                    Layout.fillWidth: true
                    required property PwLinkGroup modelData
                    // modelData 在委托销毁/模型更新瞬间可能为 null，做防护避免刷警告
                    property var appNode: modelData ? modelData.source : null
                    PwObjectTracker { objects: [appCard.appNode] }

                    FormCard.AbstractFormDelegate {
                        id: appRow
                        Layout.fillWidth: true

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                Layout.alignment: Qt.AlignVCenter
                                visible: source !== ""
                                source: (appCard.appNode && appCard.appNode.properties && appCard.appNode.properties["application.icon-name"]) || (appCard.appNode ? appCard.appNode.name : "")
                                fallback: "audio-volume-high-symbolic"
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: implicitWidth
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.smallSpacing

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Kirigami.Units.smallSpacing

                                    Label {
                                        Layout.fillWidth: true
                                        text: root.appLabel(appCard.appNode)
                                        elide: Text.ElideRight
                                        font.bold: !root.nodeMuted(appCard.appNode)
                                    }

                                    Label {
                                        text: Math.round(root.nodeVolume(appCard.appNode) * 100) + "%"
                                        font: Kirigami.Theme.smallFont
                                        color: Kirigami.Theme.disabledTextColor
                                    }
                                }

                                // 迷你音量条
                                Rectangle {
                                    id: appSlider
                                    Layout.fillWidth: true
                                    implicitHeight: 6
                                    color: Qt.rgba(1, 1, 1, 0.1)
                                    radius: height / 2

                                    Rectangle {
                                        id: progressFill
                                        height: parent.height
                                        width: seekMa.pressed
                                            ? Math.min(Math.max(0, seekMa.mouseX), appSlider.width)
                                            : appSlider.width * root.nodeVolume(appCard.appNode)
                                        radius: parent.radius
                                        color: Kirigami.Theme.highlightColor
                                        opacity: root.nodeMuted(appCard.appNode) ? 0.5 : 1.0
                                        Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                                    }

                                    Rectangle {
                                        x: progressFill.width - width / 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: "white"
                                        visible: seekMa.containsMouse || seekMa.pressed
                                        scale: seekMa.pressed ? 1.2 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100 } }
                                    }

                                    MouseArea {
                                        id: seekMa
                                        hoverEnabled: true
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        // 滚轮放行给外层 Flickable：MouseArea 默认可能吞掉 wheel，
                                        // 显式 accepted=false 保证悬停在迷你音量条上也能滚列表
                                        onWheel: (wheel) => {
                                            wheel.accepted = false;
                                        }
                                        onPressed: {
                                            if (!appCard.appNode || !appCard.appNode.audio)
                                                return;
                                            appCard.appNode.audio.volume = Math.min(Math.max(0, mouse.x / appSlider.width), 1.0);
                                        }
                                        onReleased: {
                                            if (!appCard.appNode || !appCard.appNode.audio)
                                                return;
                                            appCard.appNode.audio.volume = Math.min(Math.max(0, mouse.x / appSlider.width), 1.0);
                                        }
                                        onPositionChanged: (mouse) => {
                                            if (pressed && appCard.appNode && appCard.appNode.audio)
                                                appCard.appNode.audio.volume = Math.min(Math.max(0, mouse.x / appSlider.width), 1.0);
                                        }
                                    }
                                }
                            }

                            ToolButton {
                                icon.name: root.nodeMuted(appCard.appNode) ? "audio-volume-muted" : "audio-volume-high"
                                icon.color: root.nodeMuted(appCard.appNode) ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
                                display: AbstractButton.IconOnly
                                flat: true
                                ToolTip.delay: Qt.styleHints.mousePressAndHoldInterval
                                ToolTip.visible: hovered
                                ToolTip.text: root.nodeMuted(appCard.appNode) ? qsTr("解除静音") : qsTr("静音")
                                onClicked: {
                                    if (appCard.appNode && appCard.appNode.audio)
                                        appCard.appNode.audio.muted = !appCard.appNode.audio.muted;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Kirigami.PlaceholderMessage {
        visible: appTracker.linkGroups.length === 0
        text: qsTr("没有正在播放音频的应用")
        icon.name: "audio-volume-muted"
    }
}
