import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Notifications
import qs.Config
import qs.Services
import qs.Widget.common
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 通知中心（点顶栏铃铛 / qs ipc call notif toggle 打开）。
// 结构与 NetworkWidget / ClipboardHistoryPopup 一致：SlideWindow + FormCard。
// 不用 FormButtonDelegate（它内部的 Label 带 width: parent.width + Wrap，
// 弹窗从隐藏变可见时会形成宽度↔换行↔隐式高度的循环，主线程 100%）。
SlideWindow {
    id: root
    title: qsTr("通知中心")
    icon: "notifications-symbolic"
    // 高度贴着内容走：一两条时不留一大片空白，条数多了封顶后滚动
    windowHeight: Math.round(Math.max(190, Math.min(560, contentHeight + Kirigami.Units.largeSpacing)))

    // 面板自己请求关闭（Esc / 外部状态变化），由调用方把 WidgetState.notifOpen 置 false。
    // 不要直接写 visible = false，visible 绑定在外部属性上，赋值会破坏绑定。
    signal closeRequested()

    Shortcut {
        sequence: "Escape"
        onActivated: root.closeRequested()
    }

    // ==================== 标题栏工具 ====================
    headerTools: RowLayout {
        spacing: Kirigami.Units.smallSpacing

        ToolButton {
            checkable: true
            checked: NotificationManager.dnd
            onToggled: NotificationManager.dnd = checked
            contentItem: Kirigami.Icon {
                source: parent.checked ? "notifications-disabled-symbolic" : "notifications-symbolic"
                color: parent.checked ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            }        }

        ToolButton {
            enabled: NotificationManager.count > 0
            onClicked: NotificationManager.dismissAll()
            contentItem: Kirigami.Icon {
                source: "edit-clear-all"
                color: parent.enabled
                    ? (parent.hovered ? Kirigami.Theme.highlightColor : Kirigami.Theme.negativeTextColor)
                    : Kirigami.Theme.disabledTextColor
            }        }
    }

    // ==================== 列表 ====================
    Repeater {
        // 面板没打开时模型为空：绝不为历史通知预先建好卡片
        model: root.visible ? NotificationManager.snapshot : []

        FormCard.FormCard {
            id: notifCard
            Layout.fillWidth: true
            // Repeater 注入的 modelData 提到外层，内层 delegate 不再声明 required modelData
            property var notifData: modelData
            property bool critical: notifData && notifData.urgency === NotificationUrgency.Critical

            FormCard.AbstractFormDelegate {
                id: notifRow
                Layout.fillWidth: true
                onClicked: {
                    const actions = notifCard.notifData.actions;
                    if (actions && actions.length > 0)
                        actions[0].invoke();
                }

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignTop
                        source: {
                            const n = notifCard.notifData;
                            if (!n)
                                return "notifications";
                            return n.appIcon || n.image || "notifications";
                        }
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: implicitWidth
                        color: notifCard.critical ? Kirigami.Theme.negativeTextColor
                            : (notifRow.hovered ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            Label {
                                Layout.fillWidth: true
                                text: notifCard.notifData
                                    ? String(notifCard.notifData.summary).substring(0, 300)
                                    : ""
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                font.weight: Font.DemiBold
                                color: notifCard.critical ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                            }

                            // 到达时间：历史超过 NotificationManager.historyRetentionMs
                            // 就会连同这条一起注销掉
                            Label {
                                Layout.alignment: Qt.AlignVCenter
                                visible: text !== ""
                                text: notifCard.notifData
                                    ? NotificationManager.timeLabel(notifCard.notifData.timestamp)
                                    : ""
                                font: Kirigami.Theme.smallFont
                                color: Kirigami.Theme.disabledTextColor
                            }
                        }

                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: {
                                const n = notifCard.notifData;
                                if (!n)
                                    return "";
                                // 先截断再压缩空白：正文可能是几 MB，正则会卡住
                                const body = String(n.body || "").substring(0, 300).replace(/\s+/g, " ").trim();
                                const app = n.appName || "";
                                if (body === "")
                                    return app;
                                return app === "" ? body : app + " · " + body;
                            }
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.disabledTextColor
                        }

                        // 通知自带的按钮，直接内联，不用 Menu
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: visible ? Kirigami.Units.smallSpacing : 0
                            spacing: Kirigami.Units.smallSpacing
                            visible: notifCard.notifData ? notifCard.notifData.actions.length > 0 : false

                            Repeater {
                                model: notifCard.notifData ? notifCard.notifData.actions : []

                                delegate: Button {
                                    required property var modelData
                                    text: modelData.text
                                    flat: true
                                    onClicked: modelData.invoke()
                                }
                            }
                        }
                    }

                    ToolButton {
                        Layout.alignment: Qt.AlignTop
                        icon.name: "window-close"
                        opacity: notifRow.hovered ? 1 : 0
                        enabled: notifRow.hovered
                        onClicked: notifCard.notifData.dismiss()
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                    }
                }
            }
        }
    }

    // ==================== 空状态 ====================
    Kirigami.PlaceholderMessage {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Kirigami.Units.largeSpacing * 2
        visible: NotificationManager.count === 0
        icon.name: NotificationManager.dnd ? "notifications-disabled-symbolic" : "notifications-none-symbolic"
        text: NotificationManager.dnd ? qsTr("勿扰模式已开启") : qsTr("没有新通知")
        explanation: NotificationManager.dnd
            ? qsTr("新通知会静默进入通知中心，但不会弹出提示。")
            : qsTr("有应用发通知时会出现在这里。")
    }
}
