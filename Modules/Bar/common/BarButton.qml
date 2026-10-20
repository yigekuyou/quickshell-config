import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import qs.Config
import org.kde.kirigami as Kirigami

// ============================================================================
// 顶栏按钮的统一外观与交互
// ============================================================================
// 顶栏原本每个部件各抄一份胶囊样式，实际是 4 种根类型（ShadowedRectangle /
// Rectangle / AbstractCard / Item）、3 种背景色来源、2 种圆角、悬停反馈有的
// 部件有有的没有。这个文件把它们收敛成一份：
//
//   胶囊底 ：ShadowedRectangle + Sizes.cornerRadius + 半透明背景 + 细描边
//   状态   ：idle → hover → pressed，checked（对应面板已打开）走高亮描边
//   交互   ：HoverHandler（手型光标）+ TapHandler（左/中/右键）+ WheelHandler（可选滚轮）
//
// 三种用法（可混用）：
//   1) 图标 + 文字   BarButton { icon: "audio-volume-high"; text: "50%" }
//   2) 只有图标      BarButton { icon: "..."; square: true; horizontalPadding: 0 }
//   3) 任意内容      BarButton { content: Component { RowLayout { ... } } }
//
// 注意：默认属性仍是 ShadowedRectangle 的 data，所以面板（ClipboardWidget /
// NetworkWidget / NotificationWidget …）照旧直接写在 BarButton 里面当子对象，
// 不会掉进内部布局里。
Kirigami.ShadowedRectangle {
    id: root

    // ======================= 内容 =======================
    property string icon: ""
    // 所在分区：left / center / right，决定图标/留白/间距取哪一套设置
    property string section: "left"
    property real iconSize: Sizes.secIcon(root.section)
    property string text: ""
    // -1 = 不限宽；>0 = 文字超过这个宽度用省略号截断
    property real textMaxWidth: -1
    property bool textBold: false
    // 角标文字（通常是未读数），空字符串则不显示
    property string badge: ""
    // 任意内容，排在内置的 icon / text 之前（Workspaces、Tray 这类用）
    property Component content: null
    // 图标外围的进度环（0..1，< 0 不画）：百分比画在图标外圈
    property real progress: -1
    // 环的直径 = iconSize * ringScale；线宽 ringWidth
    property real ringScale: Sizes.barRingScale
    property real ringWidth: Sizes.barRingWidth
    property real ringTrackOpacity: Sizes.barRingTrackOpacity
    readonly property bool ringShown: root.progress >= 0 && Sizes.barRing
    // 直径跟着图标走，上限是栏高（Sizes.ringSize 里夹好）
    readonly property real ringSize: Sizes.ringSize(root.iconSize)

    // ======================= 状态 =======================
    // 对应“按钮背后的面板已打开”，用来点亮描边与背景
    property bool checked: false
    property bool interactive: true
    // 滚轮：开了才会发 scrolled(delta)，delta 已带好正负
    property bool scrollEnabled: false
    property real scrollStep: 0.05

    readonly property bool hovered: hoverHandler.hovered
    readonly property bool pressed: tapLeft.pressed

    // ======================= 外观令牌 =======================
    // 想单独改某个按钮就覆盖这几个，别在外部重写 color / radius
    property color baseColor: Kirigami.Theme.backgroundColor
    // 注意：没有 Kirigami.Theme.dividerColor（这套 Kirigami 里不存在，
    // 读它是 undefined，会报 "Unable to assign [undefined] to QColor"）。
    // 描边一律用 textColor + 低透明度，跟 Cava 原来那条 1px 细线一个做法。
    property color borderColor: Kirigami.Theme.textColor
    property real borderOpacity: 0.15
    property real borderCheckedOpacity: 0.5
    property color accentColor: Kirigami.Theme.highlightColor
    property color contentColor: root.filled ? root.onFillColor
                                             : (root.checked ? root.accentColor : Kirigami.Theme.textColor)
    property real idleOpacity: 0.5
    property real hoverOpacity: 0.75
    property real pressedOpacity: 0.9
    property real horizontalPadding: Sizes.secPad(root.section)
    property real spacing: Sizes.secGap(root.section)
    // 正方形（只放一个图标时用，配合 horizontalPadding: 0）
    property bool square: false
    // 实心底（危险按钮）：走 fillColor + onFillColor，不再叠透明度
    property bool filled: false
    property color fillColor: root.baseColor
    property color onFillColor: Kirigami.Theme.backgroundColor
    property bool shadowEnabled: true
    readonly property real shadowSize: root.shadowEnabled ? Math.round(Kirigami.Units.gridUnit * 0.55) : 0
    readonly property real shadowYOffset: root.shadowEnabled ? 2 : 0

    // ======================= 信号 =======================
    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal scrolled(real delta)

    // ======================= 尺寸 =======================
    implicitHeight: Sizes.barHeight
    readonly property real contentWidth: contentLayout.implicitWidth + root.horizontalPadding * 2
    implicitWidth: root.square ? root.implicitHeight : root.contentWidth
    radius: Sizes.cornerRadius

    // ======================= 外观 =======================
    color: root.filled
           ? root.fillColor
           : Qt.alpha(root.baseColor, root.pressed ? root.pressedOpacity
                                                   : ((root.checked || root.hovered) ? root.hoverOpacity : root.idleOpacity))
    border.width: root.filled ? 0 : 1
    border.color: Qt.alpha(root.checked ? root.accentColor : root.borderColor, root.checked ? root.borderCheckedOpacity : root.borderOpacity)
    shadow.color: Qt.rgba(0, 0, 0, 0.2)
    shadow.size: root.shadowSize
    shadow.yOffset: root.shadowYOffset

    Behavior on color {
        ColorAnimation {
            duration: Kirigami.Units.shortDuration
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Kirigami.Units.shortDuration
        }
    }

    // ======================= 内容布局 =======================
    RowLayout {
        id: contentLayout
        anchors.centerIn: parent
        spacing: root.spacing

        Loader {
            active: root.content !== null
            sourceComponent: root.content
            visible: active
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            // 环比图标大时按环的直径占位（环是居中的），
            // 否则相邻按钮的环会伸进对方的地盘里互相压住
            implicitWidth: root.ringShown ? Math.max(root.iconSize, root.ringSize) : root.iconSize
            implicitHeight: root.iconSize
            Layout.alignment: Qt.AlignVCenter

            Kirigami.Icon {
                anchors.centerIn: parent
                source: root.icon
                implicitWidth: root.iconSize
                implicitHeight: root.iconSize
                visible: root.icon !== ""
                color: root.contentColor
            }

            // 进度环（实现见 common/Ring.qml）
            Ring {
                anchors.centerIn: parent
                size: root.ringSize
                lineWidth: root.ringWidth
                trackOpacity: root.ringTrackOpacity
                color: root.checked ? root.accentColor : root.contentColor
                progress: root.ringShown ? root.progress : -1
            }
        }

        Label {
            visible: root.text !== "" && Sizes.barLabels
            text: root.text
            // 不写 font: Kirigami.Theme.smallFont —— 给 font 整组赋值会把下面的
            // font.weight 顶掉（qmllint: duplicate-property-binding）。直接给子属性。
            font.pixelSize: Math.round(root.implicitHeight * 0.42)
            font.weight: root.textBold ? Font.DemiBold : Font.Normal
            color: root.contentColor
            elide: Text.ElideRight
            maximumLineCount: 1
            Layout.maximumWidth: root.textMaxWidth > 0 ? root.textMaxWidth : -1
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            visible: root.badge !== ""
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: Math.round(Kirigami.Units.gridUnit * 0.8)
            implicitWidth: Math.max(badgeLabel.implicitWidth + Kirigami.Units.smallSpacing * 2, implicitHeight)
            radius: height / 2
            color: root.accentColor

            Label {
                id: badgeLabel
                anchors.centerIn: parent
                text: root.badge
                font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.55)
                font.weight: Font.DemiBold
                color: root.onFillColor
            }
        }
    }

    // ======================= 交互 =======================
    HoverHandler {
        id: hoverHandler
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    // 三个键各一个 TapHandler：TapHandler.tapped 的回调签名带 (eventPoint, button)
    // 参数，靠参数分键容易在版本间踩坑，分开写最省事。
    TapHandler {
        id: tapLeft
        enabled: root.interactive
        acceptedButtons: Qt.LeftButton
        onTapped: root.clicked()
    }

    TapHandler {
        enabled: root.interactive
        acceptedButtons: Qt.RightButton
        onTapped: root.rightClicked()
    }

    TapHandler {
        enabled: root.interactive
        acceptedButtons: Qt.MiddleButton
        onTapped: root.middleClicked()
    }

    // property 留空（默认值）时 WheelHandler 不会自己去改 target 的属性，
    // 只发 wheel 信号，正合这里需要。
    WheelHandler {
        enabled: root.interactive && root.scrollEnabled
        onWheel: event => root.scrolled(event.angleDelta.y > 0 ? root.scrollStep : -root.scrollStep)
    }
}