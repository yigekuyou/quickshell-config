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
// 版式照 Geometric Weather 的主屏：
//   1. 实况头图：整块淡色天空渐变 + 超大温度 + 天气现象 + 「最高 / 最低」
//   2. 空气质量：AQI 数字 + 等级文字 + 六段色带 + 指针
//   3. 详情：两列磁贴（图标 / 标题 / 大字数值 / 副行），不是竖排列表
//   4. 7 天预报：日期 / 图标 / 天气文字 / 低温 / 温度区间条 / 高温
//      区间条按本周最低 ~ 最高归一化，蓝（冷）→ 橙（暖）渐变上色，今天整行淡底高亮
//
// 卡片只画圆角 + 一层很淡的底色，不画描边阴影；头图是唯一的彩色块，
// 色调跟着实况图标走（晴=蓝、阴=灰蓝、雨=青灰、雪=浅蓝、夜=深蓝）。
// 数据全部来自 qs.Services.Weather（nmc.cn 中央气象台，由 Location 定位驱动），
// 本文件只管展示。
// ============================================================================
SlideWindow {
    id: root

    title: Weather.displayName
    icon: Weather.icon
    implicitWidth: 400
    windowHeight: Math.round(Math.max(360, Math.min(580, contentHeight + Kirigami.Units.largeSpacing)))

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

    // ==================== 设计令牌 ====================
    readonly property real _gu: Kirigami.Units.gridUnit
    readonly property real _cardRadius: _gu * 0.7
    readonly property real _tileRadius: _gu * 0.55
    readonly property real _cardPad: _gu * 0.7
    readonly property real _tilePad: _gu * 0.55
    // 温度区间条两端的固定色调（冷 / 暖）
    readonly property color _cold: "#56B4E9"
    readonly property color _warm: "#F0903C"

    // ==================== 派生展示数据 ====================
    readonly property var air: Weather.current ? Weather.current.air : null
    readonly property var today: Weather.days && Weather.days.length > 0 ? Weather.days[0] : null

    // 详情磁贴：两列网格，字段不全的直接不出现（nmc 常给 "9999"）
    readonly property var tiles: {
        const c = Weather.current;
        if (!c)
            return [];
        const out = [];

        if (!isNaN(c.feels)) {
            const diff = isNaN(c.temp) ? 0 : Math.round(c.feels - c.temp);
            out.push({
                "icon": c.feels < 0 ? "temperature-cold-symbolic" : c.feels < 18 ? "temperature-normal-symbolic" : "temperature-warm-symbolic",
                "tint": Qt.rgba(0, 0, 0, 0),
                "caption": qsTr("体感温度"),
                "value": Math.round(c.feels) + "°",
                "sub": diff === 0 ? qsTr("与实际温度相当")
                    : diff > 0 ? qsTr("比实际高 %1°").arg(diff)
                    : qsTr("比实际低 %1°").arg(-diff)
            });
        }

        if (!isNaN(c.humidity))
            out.push({
                "icon": "raindrop-symbolic",
                "tint": root._cold,
                "caption": qsTr("湿度"),
                "value": Math.round(c.humidity) + "%",
                "sub": c.humidity < 30 ? qsTr("干燥") : c.humidity < 65 ? qsTr("体感舒适") : qsTr("潮湿")
            });

        // 实况有 m/s，预报只有「3~4级」；有速度就显示速度，方向 / 等级进副行
        if (!isNaN(c.windSpeed) || c.windPower) {
            const pieces = [];
            if (c.windDir)
                pieces.push(c.windDir);
            if (c.windPower)
                pieces.push(c.windPower);
            out.push({
                "icon": "weather-clear-wind-symbolic",
                "tint": Qt.rgba(0, 0, 0, 0),
                "caption": qsTr("风"),
                "value": !isNaN(c.windSpeed) ? (c.windSpeed.toFixed(1) + " m/s") : (c.windPower || "--"),
                "sub": pieces.join(" · ")
            });
        }

        if (!isNaN(c.pressure))
            out.push({
                "icon": "speedometer-symbolic",
                "tint": Qt.rgba(0, 0, 0, 0),
                "caption": qsTr("气压"),
                "value": Math.round(c.pressure) + " hPa",
                "sub": qsTr("最近一次观测")
            });

        if (!isNaN(c.precip1h))
            out.push({
                "icon": "weather-showers-scattered",
                "tint": root._cold,
                "caption": qsTr("降水"),
                "value": (c.precip1h > 0 ? c.precip1h.toFixed(1) : "0.0") + " mm",
                "sub": qsTr("最近 1 小时")
            });

        if (c.sunrise && c.sunset)
            out.push({
                "icon": "daytime-sunrise-symbolic",
                "tint": root._warm,
                "caption": qsTr("日出 · 日落"),
                "value": c.sunrise,
                "sub": qsTr("日落 %1").arg(c.sunset)
            });

        return out;
    }

    // 空气质量等级配色（国标 6 级；在深色底上往中间调压了一点，纯色太刺眼）
    function _aqiColor(level: int): color {
        return ({
            1: "#4CAF50",   // 优
            2: "#F9A825",   // 良
            3: "#FB8C00",   // 轻度污染
            4: "#E53935",   // 中度污染
            5: "#8E24AA",   // 重度污染
            6: "#6D4C41"    // 严重污染
        })[level] || Kirigami.Theme.disabledTextColor;
    }

    readonly property color _aqiTint: root._aqiColor(root.air ? root.air.level : 0)

    // 预警等级 → 颜色（中国气象局信号色：蓝 < 黄 < 橙 < 红）
    function _alertColor(level: string): color {
        return ({
            "蓝色": "#1e88e5",
            "黄色": "#f9a825",
            "橙色": "#fb8c00",
            "红色": "#e53935"
        })[level] || Kirigami.Theme.textColor;
    }

    // 实况头图的天空底色：跟着图标挑一个，夜/雨/雪各走一套
    readonly property color _sky: {
        if (!Weather.current)
            return Kirigami.Theme.highlightColor;
        const n = Weather.current.icon || "";
        if (n.indexOf("snow") >= 0)
            return "#7FA8C9";
        if (n.indexOf("storm") >= 0)
            return "#4C5A78";
        if (n.indexOf("shower") >= 0)
            return "#3F6E8C";
        if (n.indexOf("fog") >= 0)
            return "#8A8F98";
        if (n.indexOf("clouds") >= 0 || n.indexOf("overcast") >= 0)
            return "#5D7186";
        if (n.indexOf("night") >= 0)
            return "#33406B";
        return "#4A90D9";
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

        // ---- 预警信号条（real.warn，蓝/黄/橙/红 四级）----
        Rectangle {
            id: alertBanner
            Layout.fillWidth: true
            visible: !!Weather.alert
            radius: root._cardRadius
            // 底色按预警等级取同色淡底，左边一条实色竖条点明等级
            color: Qt.alpha(root._alertColor(Weather.alert ? Weather.alert.level : ""), 0.16)
            implicitHeight: alertRow.implicitHeight + Kirigami.Units.smallSpacing * 2

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: root._cardRadius * 2
                color: root._alertColor(Weather.alert ? Weather.alert.level : "")
                radius: root._cardRadius
            }

            RowLayout {
                id: alertRow
                anchors.fill: parent
                anchors.leftMargin: root._cardRadius + Kirigami.Units.smallSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "dialog-warning-symbolic"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: Kirigami.Units.iconSizes.small
                    color: root._alertColor(Weather.alert ? Weather.alert.level : "")
                    Layout.alignment: Qt.AlignVCenter
                }

                Label {
                    Layout.fillWidth: true
                    text: (Weather.alert ? Weather.alert.text : "")
                    color: Kirigami.Theme.textColor
                    elide: Text.ElideRight
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // 整条可点开预警详情页（nmc 的 url 字段）。放在内容之上：
            // 声明在后面的同级元素吃事件在前
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (Weather.alert && Weather.alert.url)
                        Qt.openUrlExternally(Weather.alert.url);
                }
            }
        }

        // ---- 实况头图：天空渐变 + 超大温度 + 天气现象 ----
        Rectangle {
            id: hero
            Layout.fillWidth: true
            visible: !!Weather.current
            radius: root._cardRadius
            implicitHeight: heroLayout.implicitHeight + root._cardPad * 1.6
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0.0
                    color: Qt.alpha(root._sky, 0.36)
                }
                GradientStop {
                    position: 1.0
                    color: Qt.alpha(root._sky, 0.04)
                }
            }

            ColumnLayout {
                id: heroLayout
                anchors.fill: parent
                anchors.margins: root._cardPad * 1.15
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root._gu * 0.5

                    ColumnLayout {
                        Layout.fillWidth: true
                        // preferredWidth 归零：让这一列吃掉 RowLayout 的剩余宽度，
                        // 右侧图标才会被顶到卡片右边（只写 fillWidth 时列宽停在隐式宽度）
                        Layout.preferredWidth: 0
                        spacing: 0

                        Label {
                            // 大温度：几何天气的视觉主角，细字重撑开
                            text: Weather.tempText
                            font.pixelSize: root._gu * 4.0
                            font.weight: Font.Light
                            color: Kirigami.Theme.textColor
                            Layout.topMargin: -root._gu * 0.55
                            Layout.bottomMargin: -root._gu * 0.35
                        }

                        Label {
                            text: (Weather.current ? Weather.current.condition : "") || qsTr("暂无实况")
                            font.pixelSize: root._gu * 1.1
                            color: Kirigami.Theme.textColor
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Label {
                            visible: !!root.today && root.today.hi !== null && root.today.lo !== null
                            text: root.today ? qsTr("最高 %1° · 最低 %2°").arg(root.today.hi).arg(root.today.lo) : ""
                            font.pixelSize: root._gu * 0.8
                            color: Kirigami.Theme.disabledTextColor
                            Layout.topMargin: root._gu * 0.25
                        }
                    }

                    Kirigami.Icon {
                        source: Weather.icon
                        implicitWidth: root._gu * 3.2
                        implicitHeight: root._gu * 3.2
                        // 顶到右上角，和超大温度同一行对视（几何天气的摆法）
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        Layout.topMargin: root._gu * 0.1
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: root._gu * 0.55

                    Label {
                        text: Weather.current ? qsTr("更新于 %1").arg(Weather.current.publishTime) : ""
                        font.pixelSize: root._gu * 0.7
                        color: Kirigami.Theme.disabledTextColor
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Label {
                        // 省份只在有值时出现，避免空的分隔点
                        visible: !!Weather.current && !!Weather.current.province
                        text: Weather.current ? Weather.current.province : ""
                        font.pixelSize: root._gu * 0.7
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                        Layout.maximumWidth: root._gu * 8
                    }
                }
            }
        }

        // ---- 空气质量：AQI + 六段色带 ----
        Rectangle {
            Layout.fillWidth: true
            visible: !!root.air
            radius: root._cardRadius
            color: Qt.alpha(Kirigami.Theme.textColor, 0.05)
            implicitHeight: airLayout.implicitHeight + root._cardPad * 2

            ColumnLayout {
                id: airLayout
                anchors.fill: parent
                anchors.margins: root._cardPad
                spacing: root._gu * 0.3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root._gu * 0.35

                    Kirigami.Icon {
                        source: "weather-fog"
                        color: root._aqiTint
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                    }

                    Label {
                        text: qsTr("空气质量")
                        font.pixelSize: root._gu * 0.8
                        font.weight: Font.DemiBold
                        color: Kirigami.Theme.textColor
                        Layout.fillWidth: true
                    }

                    Label {
                        text: root.air && root.air.time ? root.air.time : ""
                        font.pixelSize: root._gu * 0.7
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root._gu * 0.4

                    Label {
                        text: root.air ? String(root.air.aqi) : "--"
                        font.pixelSize: root._gu * 1.9
                        font.weight: Font.DemiBold
                        color: root._aqiTint
                    }

                    Label {
                        text: root.air && root.air.text ? root.air.text : ""
                        font.pixelSize: root._gu * 0.95
                        color: root._aqiTint
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: root._gu * 0.25
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Label {
                        text: "AQI"
                        font.pixelSize: root._gu * 0.7
                        color: Kirigami.Theme.disabledTextColor
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: root._gu * 0.25
                    }
                }

                // 六段国标色带 + 当前 AQI 指针（0~300 线性）
                Item {
                    id: aqiBar
                    Layout.fillWidth: true
                    Layout.preferredHeight: 8
                    Layout.topMargin: root._gu * 0.15

                    Row {
                        anchors.fill: parent
                        spacing: 2

                        Repeater {
                            model: [1, 2, 3, 4, 5, 6]

                            delegate: Rectangle {
                                width: (aqiBar.width - 10) / 6
                                height: aqiBar.height
                                radius: 2
                                color: Qt.alpha(root._aqiColor(modelData), 0.6)
                            }
                        }
                    }

                    Rectangle {
                        readonly property real frac: Math.max(0, Math.min(1, (root.air ? root.air.aqi : 0) / 300))
                        width: 2
                        height: aqiBar.height + 4
                        y: -2
                        x: Math.max(0, Math.min(aqiBar.width - width, aqiBar.width * frac - width / 2))
                        radius: 1
                        color: Kirigami.Theme.textColor
                    }
                }
            }
        }

        // ---- 详情：两列磁贴（几何天气的招牌排版）----
        GridLayout {
            Layout.fillWidth: true
            visible: root.tiles.length > 0
            columns: 2
            columnSpacing: Kirigami.Units.smallSpacing * 1.5
            rowSpacing: Kirigami.Units.smallSpacing * 1.5

            Repeater {
                model: root.tiles

                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: tileLayout.implicitHeight + root._tilePad * 2
                    radius: root._tileRadius
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.05)

                    ColumnLayout {
                        id: tileLayout
                        anchors.fill: parent
                        anchors.margins: root._tilePad
                        spacing: 1

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root._gu * 0.25

                            Kirigami.Icon {
                                source: modelData.icon
                                // tint 透明 = 用文字色（压暗），否则用指定色
                                color: modelData.tint.a > 0 ? modelData.tint : Kirigami.Theme.textColor
                                opacity: modelData.tint.a > 0 ? 1 : 0.7
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: Kirigami.Units.iconSizes.small
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Label {
                                Layout.fillWidth: true
                                text: modelData.caption
                                font.pixelSize: root._gu * 0.72
                                color: Kirigami.Theme.disabledTextColor
                                elide: Text.ElideRight
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            text: modelData.value
                            font.pixelSize: root._gu * 1.15
                            font.weight: Font.DemiBold
                            color: Kirigami.Theme.textColor
                            elide: Text.ElideRight
                            Layout.topMargin: root._gu * 0.15
                        }

                        Label {
                            Layout.fillWidth: true
                            text: modelData.sub
                            font.pixelSize: root._gu * 0.68
                            color: Kirigami.Theme.disabledTextColor
                            elide: Text.ElideRight
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
                    font.pixelSize: root._gu * 0.8
                    font.weight: Font.DemiBold
                    color: Kirigami.Theme.textColor
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                }

                Repeater {
                    model: Weather.days

                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: dayRow.implicitHeight + root._gu * 0.3
                            radius: root._gu * 0.4
                            // 今天整行淡主色底，比只加粗字更接近几何天气的高亮
                            color: modelData.week === "今天" ? Qt.alpha(Kirigami.Theme.highlightColor, 0.12) : "transparent"

                            RowLayout {
                                id: dayRow
                                anchors.fill: parent
                                anchors.margins: root._gu * 0.15
                                spacing: Kirigami.Units.smallSpacing

                                ColumnLayout {
                                    Layout.preferredWidth: root._gu * 3.3
                                    spacing: 0

                                    Label {
                                        text: modelData.week
                                        font.pixelSize: root._gu * 0.85
                                        font.weight: modelData.week === "今天" ? Font.DemiBold : Font.Normal
                                        color: modelData.week === "今天" ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                                        elide: Text.ElideRight
                                    }

                                    Label {
                                        text: root._shortDate(modelData.date)
                                        font.pixelSize: root._gu * 0.65
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
                                    Layout.preferredWidth: root._gu * 2.6
                                    text: modelData.day
                                    font.pixelSize: root._gu * 0.75
                                    color: Kirigami.Theme.textColor
                                    elide: Text.ElideRight
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Label {
                                    Layout.preferredWidth: root._gu * 1.35
                                    text: modelData.lo === null ? "--" : (modelData.lo + "°")
                                    color: Kirigami.Theme.disabledTextColor
                                    horizontalAlignment: Text.AlignRight
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
                                    Layout.preferredWidth: root._gu * 1.35
                                    text: modelData.hi === null ? "--" : (modelData.hi + "°")
                                    font.weight: Font.DemiBold
                                    color: Kirigami.Theme.textColor
                                    horizontalAlignment: Text.AlignRight
                                    Layout.alignment: Qt.AlignVCenter
                                }
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
            text: qsTr("数据：中央气象台 nmc.cn") + (Location.coordinateText ? (" · 坐标 " + Location.coordinateText) : "")
            font.pixelSize: Kirigami.Units.gridUnit * 0.7
            color: Kirigami.Theme.disabledTextColor
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
