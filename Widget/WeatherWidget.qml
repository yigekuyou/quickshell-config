import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Services
import qs.Widget.common
import org.kde.kirigami as Kirigami

// ============================================================================
// 天气面板：几何天气（Geometric Weather）风格。
//
// 布局照着 Geometric Weather 的主屏抄：
//   * 顶部实况区：大图标 + 大温度，天气现象与「体感 · 湿度」元信息一行带过
//   * 「详情」卡片：图标 + 标题 + 右对齐数值的列表行（体感 / 湿度 / 风 / 日出日落）
//   * 「7 天预报」卡片：日期 / 图标 / 低温 / 温度区间条 / 高温
//     区间条按本周最低 ~ 最高归一化，蓝（冷）→ 橙（暖）渐变上色
//
// 卡片只画圆角 + 一层很淡的底色 + 分隔线，不画描边阴影，保持扁平透气。
// 数据全部来自 qs.Services.Weather（Open-Meteo，由 Location 坐标驱动），本文件只管展示。
// ============================================================================
SlideWindow {
    id: root

    title: Weather.displayName
    icon: Weather.icon
    implicitWidth: 380
    windowHeight: Math.round(Math.max(320, Math.min(560, contentHeight + Kirigami.Units.largeSpacing)))

    // 打开时数据还是空的（启动失败 / ipc 手动关了很久）就顺手拉一次
    onVisibleChanged: {
        if (visible && (Weather.status === "error" || Weather.status === "idle"))
            Weather.refresh();
    }

    // 头部右上角的刷新按钮：转圈那一下直接抄 NetworkWidget 的扫描按钮
    headerTools: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        ToolButton {
            id: refreshButton
            icon.name: "view-refresh-symbolic"
            icon.width: Kirigami.Units.iconSizes.small
            icon.height: Kirigami.Units.iconSizes.small
            enabled: !Weather.refreshing
            onClicked: Weather.refresh()
            ToolTip.visible: hovered
            ToolTip.text: qsTr("刷新")

            RotationAnimation on rotation {
                running: Weather.refreshing
                from: 0
                to: 360
                loops: Animation.Infinite
                duration: 1000
                onRunningChanged: if (!running)
                    refreshButton.rotation = 0
            }
        }
    }

    // ==================== 卡片公共尺寸 ====================
    readonly property real _cardRadius: Kirigami.Units.gridUnit * 0.7
    readonly property real _cardPad: Kirigami.Units.gridUnit * 0.75
    // 温度区间条两端的固定色调（冷 / 暖），详情图标也复用这两个色，整块面板颜色才成套
    readonly property color _cold: "#56B4E9"
    readonly property color _warm: "#F0903C"

    // ==================== 派生展示数据 ====================
    readonly property var details: {
        if (!Weather.current)
            return [];
        const c = Weather.current;
        const t = Math.round(c.feels);
        return [
            {
                // 体感按温度换冷 / 常 / 暖三个温度计图标
                "icon": t < 0 ? "temperature-cold-symbolic" : t < 18 ? "temperature-normal-symbolic" : "temperature-warm-symbolic",
                "iconColor": Qt.rgba(0, 0, 0, 0),
                "caption": qsTr("体感温度"),
                "value": t + "°"
            },
            {
                "icon": "raindrop-symbolic",
                "iconColor": root._cold,
                "caption": qsTr("湿度"),
                "value": Math.round(c.humidity) + "%"
            },
            {
                "icon": "weather-clear-wind-symbolic",
                "iconColor": Qt.rgba(0, 0, 0, 0),
                "caption": qsTr("风"),
                "value": c.windDir ? qsTr("%1风 %2 m/s").arg(c.windDir).arg(Math.round(c.windSpeed))
                                   : (Math.round(c.windSpeed) + " m/s")
            },
            {
                "icon": "daytime-sunrise-symbolic",
                "iconColor": root._warm,
                "caption": qsTr("日出 · 日落"),
                "value": c.sunrise && c.sunset ? (c.sunrise + " / " + c.sunset) : "--"
            }
        ];
    }

    // 逐日温度条的归一化范围：取本周最低 / 最高
    readonly property real _weekLo: {
        let m = Infinity;
        for (const d of Weather.days)
            if (d.lo !== null && d.lo < m)
                m = d.lo;
        return m === Infinity ? 0 : m;
    }
    readonly property real _weekHi: {
        let m = -Infinity;
        for (const d of Weather.days)
            if (d.hi !== null && d.hi > m)
                m = d.hi;
        return m === -Infinity ? 0 : m;
    }

    function _norm(t: real): real {
        const span = root._weekHi - root._weekLo;
        if (span <= 0)
            return 0.5;
        return Math.max(0, Math.min(1, (t - root._weekLo) / span));
    }

    function _shortDate(dateStr: string): string {
        const parts = (dateStr || "").split("-");
        return parts.length >= 3 ? (parts[1] + "/" + parts[2]) : "";
    }

    // ==================== 内容 ====================
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.largeSpacing

        // ---- 无数据时的占位（加载中 / 失败）----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            visible: !Weather.current
            spacing: Kirigami.Units.mediumSpacing

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                source: Weather.status === "error" ? "weather-none-available" : "weather-clear"
                implicitWidth: Kirigami.Units.iconSizes.huge
                implicitHeight: Kirigami.Units.iconSizes.huge
                opacity: 0.8
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: Weather.status === "error" ? ("更新失败：" + Weather.message) : qsTr("正在获取天气…")
                color: Weather.status === "error" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                Layout.maximumWidth: root.implicitWidth - Kirigami.Units.gridUnit * 3
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                visible: Weather.status === "error"
                icon.name: "view-refresh-symbolic"
                text: qsTr("重试")
                onClicked: Weather.refresh()
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: Weather.status === "error"
                text: qsTr("也可手动指定城市：settings/settings.json → weather.city")
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Kirigami.Units.gridUnit * 0.75
            }
        }

        // ---- 失败但有旧数据：顶上一条可重试的细条 ----
        Rectangle {
            Layout.fillWidth: true
            visible: Weather.current && Weather.status === "error"
            radius: Kirigami.Units.smallSpacing
            color: Qt.alpha(Kirigami.Theme.negativeTextColor, 0.12)
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.negativeTextColor, 0.3)
            implicitHeight: errorRow.implicitHeight + Kirigami.Units.smallSpacing * 2

            RowLayout {
                id: errorRow
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing

                Label {
                    Layout.fillWidth: true
                    text: qsTr("更新失败：%1").arg(Weather.message)
                    color: Kirigami.Theme.negativeTextColor
                    elide: Text.ElideRight
                }

                ToolButton {
                    icon.name: "view-refresh-symbolic"
                    icon.width: Kirigami.Units.iconSizes.small
                    icon.height: Kirigami.Units.iconSizes.small
                    enabled: !Weather.refreshing
                    onClicked: Weather.refresh()
                }
            }
        }

        // ---- 实况：大图标 + 大温度 ----
        ColumnLayout {
            Layout.fillWidth: true
            visible: !!Weather.current
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: Weather.icon
                    implicitWidth: Kirigami.Units.iconSizes.huge
                    implicitHeight: Kirigami.Units.iconSizes.huge
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    Label {
                        text: Weather.tempText
                        font.pixelSize: Kirigami.Units.gridUnit * 4.0
                        font.weight: Font.Light
                        color: Kirigami.Theme.textColor
                    }

                    Label {
                        text: (Weather.current ? Weather.current.condition : "") || qsTr("暂无实况")
                        font.pixelSize: Kirigami.Units.gridUnit * 1.15
                        color: Kirigami.Theme.textColor
                    }

                    // 元信息一行：体感 + 湿度（跟着实况走，比四格里重复一遍更紧凑）
                    Label {
                        visible: !!Weather.current
                        text: Weather.current ? (qsTr("体感 %1° · 湿度 %2%")
                            .arg(Math.round(Weather.current.feels))
                            .arg(Math.round(Weather.current.humidity))) : ""
                        font.pixelSize: Kirigami.Units.gridUnit * 0.85
                        color: Kirigami.Theme.disabledTextColor
                        Layout.topMargin: Kirigami.Units.smallSpacing
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: Weather.current ? (Weather.current.publishTime + qsTr(" 发布")) : ""
                font.pixelSize: Kirigami.Units.gridUnit * 0.75
                color: Kirigami.Theme.disabledTextColor
            }
        }

        // ---- 详情卡片：图标 + 标题 + 右对齐数值 ----
        Rectangle {
            Layout.fillWidth: true
            visible: details.length > 0
            radius: root._cardRadius
            color: Qt.alpha(Kirigami.Theme.textColor, 0.05)
            implicitHeight: detailLayout.implicitHeight + root._cardPad * 2

            ColumnLayout {
                id: detailLayout
                anchors.fill: parent
                anchors.margins: root._cardPad
                spacing: 0

                Label {
                    text: qsTr("详情")
                    font.pixelSize: Kirigami.Units.gridUnit * 0.8
                    font.weight: Font.DemiBold
                    color: Kirigami.Theme.textColor
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }

                Repeater {
                    model: root.details

                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: modelData.icon
                                // iconColor 带透明度 = 指定色（蓝/橙）；否则压暗用文字色
                                color: modelData.iconColor.a > 0 ? modelData.iconColor : Kirigami.Theme.textColor
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: Kirigami.Units.iconSizes.small
                                Layout.alignment: Qt.AlignVCenter
                                opacity: modelData.iconColor.a > 0 ? 1 : 0.75
                            }

                            Label {
                                text: modelData.caption
                                font.pixelSize: Kirigami.Units.gridUnit * 0.9
                                color: Kirigami.Theme.textColor
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Item {
                                Layout.fillWidth: true
                            }

                            Label {
                                text: modelData.value
                                font.pixelSize: Kirigami.Units.gridUnit * 0.9
                                font.weight: Font.DemiBold
                                color: Kirigami.Theme.textColor
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Layout.topMargin: index === 0 ? 0 : Kirigami.Units.gridUnit * 0.55
                            Layout.bottomMargin: index === root.details.length - 1 ? 0 : Kirigami.Units.gridUnit * 0.55
                        }

                        Kirigami.Separator {
                            Layout.fillWidth: true
                            visible: index < root.details.length - 1
                        }
                    }
                }
            }
        }

        // ---- 7 天预报卡片 ----
        Rectangle {
            Layout.fillWidth: true
            visible: Weather.days.length > 0
            radius: root._cardRadius
            color: Qt.alpha(Kirigami.Theme.textColor, 0.05)
            implicitHeight: forecastLayout.implicitHeight + root._cardPad * 2

            ColumnLayout {
                id: forecastLayout
                anchors.fill: parent
                anchors.margins: root._cardPad
                spacing: 0

                Label {
                    text: qsTr("7 天预报")
                    font.pixelSize: Kirigami.Units.gridUnit * 0.8
                    font.weight: Font.DemiBold
                    color: Kirigami.Theme.textColor
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }

                Repeater {
                    model: Weather.days

                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            Layout.topMargin: index === 0 ? 0 : Kirigami.Units.gridUnit * 0.5
                            Layout.bottomMargin: index === Weather.days.length - 1 ? 0 : Kirigami.Units.gridUnit * 0.5

                            ColumnLayout {
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 3.6
                                spacing: 0

                                Label {
                                    text: modelData.week
                                    font.pixelSize: Kirigami.Units.gridUnit * 0.9
                                    // 今天高亮：主色 + 半粗
                                    font.weight: modelData.week === "今天" ? Font.DemiBold : Font.Normal
                                    color: modelData.week === "今天" ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                                    elide: Text.ElideRight
                                }

                                Label {
                                    text: root._shortDate(modelData.date)
                                    font.pixelSize: Kirigami.Units.gridUnit * 0.7
                                    color: Kirigami.Theme.disabledTextColor
                                }
                            }

                            Kirigami.Icon {
                                source: modelData.dayIcon
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Label {
                                text: modelData.lo === null ? "--" : (modelData.lo + "°")
                                color: Kirigami.Theme.disabledTextColor
                                Layout.alignment: Qt.AlignVCenter
                            }

                            // 温度区间条：本周最低 ~ 最高归一化后的一段
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 6
                                Layout.alignment: Qt.AlignVCenter

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 3
                                    color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
                                }

                                Rectangle {
                                    readonly property real fromPos: modelData.lo === null ? 0 : root._norm(modelData.lo)
                                    readonly property real toPos: modelData.hi === null ? 1 : root._norm(modelData.hi)
                                    y: (parent.height - height) / 2
                                    x: parent.width * fromPos
                                    width: Math.max(6, parent.width * (toPos - fromPos))
                                    height: 6
                                    radius: 3

                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop {
                                            position: 0.0
                                            color: root._cold
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: root._warm
                                        }
                                    }
                                }
                            }

                            Label {
                                text: modelData.hi === null ? "--" : (modelData.hi + "°")
                                font.weight: Font.DemiBold
                                color: Kirigami.Theme.textColor
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        Kirigami.Separator {
                            Layout.fillWidth: true
                            visible: index < Weather.days.length - 1
                        }
                    }
                }
            }
        }

        // ---- 脚注：来源 + 坐标 ----
        Label {
            Layout.fillWidth: true
            text: qsTr("数据：Open-Meteo") + (Location.coordinateText ? (" · 坐标 " + Location.coordinateText) : "")
            font.pixelSize: Kirigami.Units.gridUnit * 0.7
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
