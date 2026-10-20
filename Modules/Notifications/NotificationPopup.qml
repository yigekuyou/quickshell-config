import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications
import qs.Services
import org.kde.kirigami as Kirigami

// 单张通知弹窗卡片。
//
// 注意这里是普通 Item，不是窗口：窗口在 NotificationPopupStack.qml 里，
// 整摞弹窗共用一个 layer-shell 表面。旧实现每张通知创建一个 PopupWindow 并
// anchor 到 barWindow，那个 id 只在 Wallpaper/Notif.qml 的独立进程里存在，
// 在主进程里就是 ReferenceError；再叠上 Instantiator + destroy() 手动销毁
// 自己托管的对象，就会把 qs 直接带走。
Item {
    id: root

    // ListView 会把 modelData 注入到这个 required 属性上（外部组件作为 delegate
    // 时，只有声明成 required 的 modelData/index 才会被注入；直接写
    // `notification: modelData` 会报 ReferenceError: modelData is not defined）
    required property var modelData

    readonly property var n: modelData
    readonly property bool critical: !!n && n.urgency === NotificationUrgency.Critical
    readonly property bool hovered: hover.hovered

    // 自动关闭时长：0 表示不自动关（关键通知 / resident / 客户端明确要求 0）
    readonly property int autoCloseMs: {
        if (!n)
            return 0;
        if (n.urgency === NotificationUrgency.Critical)
            return 0;
        if (n.resident)
            return 0;
        const t = Number(n.expireTimeout);
        if (t === 0)
            return 0;
        if (t < 0)
            return NotificationManager.defaultTimeout;
        return Math.max(1500, Math.min(t, NotificationManager.maxTimeout));
    }

    // 应用发来的正文可能是几 MB 的字符串：直接丢给 Text 折行会卡死主线程，
    // 这里先截断（显示上也用不到那么多）
    function clamp(value, maxLength) {
        const s = String(value === undefined || value === null ? "" : value);
        return s.length > maxLength ? s.substring(0, maxLength) + "…" : s;
    }

    readonly property string iconSource: {
        if (!n)
            return "notifications";
        if (n.appIcon && n.appIcon !== "")
            return n.appIcon;
        if (n.image && n.image !== "")
            return n.image;
        return "notifications";
    }

    // 剩余显示时间（毫秒），给底部进度条用
    property int remainingMs: 0

    implicitHeight: card.implicitHeight
    implicitWidth: card.implicitWidth

    Rectangle {
        id: card
        width: root.width
        implicitHeight: layout.implicitHeight + Kirigami.Units.largeSpacing * 2
        radius: Kirigami.Units.gridUnit * 0.5
        color: Kirigami.Theme.backgroundColor
        border.width: root.critical ? 2 : 1
        border.color: root.critical
            ? Kirigami.Theme.negativeTextColor
            : Qt.alpha(Kirigami.Theme.textColor, 0.15)
        clip: true

        ColumnLayout {
            id: layout
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: Kirigami.Units.largeSpacing
            }
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                // 应用图标放在淡色圆角底上，没有图标时也有形状
                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: Kirigami.Units.gridUnit * 2.2
                    implicitHeight: implicitWidth
                    radius: Kirigami.Units.smallSpacing
                    color: Qt.alpha(Kirigami.Theme.highlightColor, 0.14)

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        width: parent.width * 0.62
                        height: width
                        source: root.iconSource
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Label {
                        Layout.fillWidth: true
                        text: root.n ? (root.n.appName || qsTr("通知")) : ""
                        elide: Text.ElideRight
                        opacity: 0.65
                        font: Kirigami.Theme.smallFont
                    }
                    Label {
                        Layout.fillWidth: true
                        text: root.n ? root.clamp(root.n.summary, 300) : ""
                        elide: Text.ElideRight
                        font.weight: Font.DemiBold
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }
                }

                ToolButton {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: Kirigami.Units.gridUnit * 1.4
                    implicitHeight: Kirigami.Units.gridUnit * 1.4
                    opacity: root.hovered ? 1 : 0.45
                    onClicked: NotificationManager.dismiss(root.n)
                    contentItem: Kirigami.Icon {
                        source: "window-close-symbolic"
                        color: parent.hovered ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    }                }
            }

            Label {
                Layout.fillWidth: true
                Layout.topMargin: 2
                visible: text !== ""
                text: root.n ? root.clamp(root.n.body, 1200) : ""
                wrapMode: Text.WordWrap
                maximumLineCount: 8
                opacity: 0.8
                font: Kirigami.Theme.smallFont
            }

            // 通知自带的操作按钮（内联，不用 Menu：弹窗/浮层里开 Menu 需要
            // Overlay.overlay，非 ApplicationWindow 环境下是 null）
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: visible ? Kirigami.Units.smallSpacing : 0
                spacing: Kirigami.Units.smallSpacing
                visible: root.n ? root.n.actions.length > 0 : false

                Repeater {
                    model: root.n ? root.n.actions : []

                    delegate: Button {
                        // 声明成 required，明确拿的是“操作”这一层的 modelData，
                        // 而不是外层卡片的同名字符串
                        required property var modelData
                        text: modelData.text
                        flat: true
                        onClicked: {
                            modelData.invoke();
                            NotificationManager.removePopup(root.n);
                        }
                    }
                }
            }
        }

        // 剩余时间条：hover 时暂停
        Rectangle {
            anchors {
                left: parent.left
                bottom: parent.bottom
            }
            height: 2
            width: root.autoCloseMs > 0 ? parent.width * (root.remainingMs / root.autoCloseMs) : 0
            visible: root.autoCloseMs > 0
            color: root.critical ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
            opacity: 0.55
        }

        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            onTapped: {
                if (!root.n)
                    return;
                // 有默认操作就执行，否则视作“已读并关闭”
                if (root.n.actions.length > 0) {
                    root.n.actions[0].invoke();
                    NotificationManager.removePopup(root.n);
                } else {
                    NotificationManager.dismiss(root.n);
                }
            }
        }
    }

    // 自己数秒而不是用 NumberAnimation：animation 的 paused 在非 running 状态下
    // 赋值会刷 "setPaused() cannot be used when animation isn't running"。
    Timer {
        interval: 100
        repeat: true
        running: root.autoCloseMs > 0 && !root.hovered
        onTriggered: {
            root.remainingMs -= interval;
            if (root.remainingMs <= 0)
                NotificationManager.expire(root.n);
        }
    }

    onAutoCloseMsChanged: root.remainingMs = root.autoCloseMs

    // 进场
    Component.onCompleted: {
        root.remainingMs = root.autoCloseMs;
        entrance.start();
    }

    NumberAnimation {
        id: entrance
        target: card
        property: "opacity"
        from: 0
        to: 1
        duration: Kirigami.Units.shortDuration
        easing.type: Easing.OutCubic
    }
}
