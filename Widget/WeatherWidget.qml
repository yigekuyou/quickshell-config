import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Services
import qs.Widget.common
import org.kde.kirigami as Kirigami

// ============================================================================
// 天气面板：几何天气（Geometric Weather）风格 —— 大图标 + 大温度，
// 扁平两格实况、带温度区间条的逐日列表。不加卡片边框，呼吸感为主。
//
// 数据全部来自 qs.Services.Weather（Open-Meteo，由 Location 坐标驱动），
// 本文件只管展示。
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

    // ==================== 派生展示数据 ====================
    readonly property var details: {
        if (!Weather.current)
            return [];
        const c = Weather.current;
        return [
            {
                "caption": qsTr("体感"),
                "value": Math.round(c.feels) + "°"
            },
            {
                "caption": qsTr("湿度"),
                "value": Math.round(c.humidity) + "%"
            },
            {
                "caption": qsTr("风"),
                "value": c.windDir ? qsTr("%1风 %2 m/s").arg(c.windDir).arg(Math.round(c.windSpeed))
                                   : (Math.round(c.windSpeed) + " m/s")
            },
            {
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
        RowLayout {
            Layout.fillWidth: true
            visible: !!Weather.current
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
                spacing: 2

                Label {
                    text: Weather.tempText
                    font.pixelSize: Kirigami.Units.gridUnit * 3.4
                    font.weight: Font.Light
                    color: Kirigami.Theme.textColor
                }

                Label {
                    text: (Weather.current ? Weather.current.condition : "") || qsTr("暂无实况")
                    font.pixelSize: Kirigami.Units.gridUnit * 1.1
                    color: Kirigami.Theme.textColor
                }

                Label {
                    text: Weather.current ? (Weather.current.city + " · " + Weather.current.publishTime + qsTr(" 发布")) : ""
                    font.pixelSize: Kirigami.Units.gridUnit * 0.8
                    color: Kirigami.Theme.disabledTextColor
                }
            }
        }

        // ---- 实况四格 ----
        GridLayout {
            Layout.fillWidth: true
            visible: details.length > 0
            columns: 2
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing

            Repeater {
                model: root.details

                delegate: Rectangle {
                    Layout.fillWidth: true
                    radius: Kirigami.Units.smallSpacing
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.05)
                    implicitHeight: cellCol.implicitHeight + Kirigami.Units.smallSpacing * 2

                    ColumnLayout {
                        id: cellCol
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: 0

                        Label {
                            text: modelData.caption
                            font.pixelSize: Kirigami.Units.gridUnit * 0.72
                            color: Kirigami.Theme.disabledTextColor
                        }

                        Label {
                            text: modelData.value
                            font.pixelSize: Kirigami.Units.gridUnit * 1.0
                            font.weight: Font.DemiBold
                            color: Kirigami.Theme.textColor
                        }
                    }
                }
            }
        }

        // ---- 逐日：日期 / 图标 / 低温 / 区间条 / 高温 ----
        ColumnLayout {
            Layout.fillWidth: true
            visible: Weather.days.length > 0
            spacing: 0

            Repeater {
                model: Weather.days

                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    ColumnLayout {
                        Layout.preferredWidth: Kirigami.Units.gridUnit * 3.6
                        spacing: 0

                        Label {
                            text: modelData.week
                            font.pixelSize: Kirigami.Units.gridUnit * 0.9
                            color: Kirigami.Theme.textColor
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
                                    color: "#56B4E9"
                                }
                                GradientStop {
                                    position: 1.0
                                    color: "#F0903C"
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
