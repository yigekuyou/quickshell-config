// 剪贴板历史面板。与 NetworkWidget / NotificationWidget 同属 qs.Widget：
// 由顶栏入口 Modules/Bar/ClipboardManager 的 ClipboardStatus 实例化并锚定，
// 不属于 Bar 目录结构本身。

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import qs.Config
import qs.Services
import qs.Widget.common

// 结构与 NotificationWidget 一致：SlideWindow + Repeater + FormCard。
// 高度随内容自适应（少则贴内容，多则封顶后由内部 Flickable 滚动），
// 不再是 ListView + 固定 windowHeight 的观感。
SlideWindow {
    id: root

    // 用于刷新“N 分钟前”，只在面板可见时走动，避免后台空转
    property double now: Date.now()

    // 弹窗自己请求关闭（Esc / 选中条目），由调用方把 popupOpen 置 false。
    // 不要直接写 visible = false：visible 通常绑定在外部属性上，赋值会破坏绑定。
    signal closeRequested()

    // ==================== 格式化 ====================
    function preview(text) {
        const t = String(text).replace(/\s+/g, " ").trim();
        return t.length > 120 ? t.substring(0, 120) + "…" : t;
    }

    function iconFor(text) {
        const t = String(text).trim();
        if (/^(https?|ftp|file):\/\//i.test(t))
            return "internet-web-browser-symbolic";

        return "edit-paste-symbolic";
    }

    function relativeTime(ts) {
        const diff = Math.max(0, root.now - ts);
        const minutes = Math.floor(diff / 60000);
        if (minutes < 1)
            return qsTr("刚刚");

        if (minutes < 60)
            return qsTr("%1 分钟前").arg(minutes);

        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return qsTr("%1 小时前").arg(hours);

        const days = Math.floor(hours / 24);
        if (days < 7)
            return qsTr("%1 天前").arg(days);

        return Qt.formatDateTime(new Date(ts), "yyyy-MM-dd");
    }

    function meta(text, ts) {
        const str = String(text);
        const parts = [];
        if (ts > 0)
            parts.push(root.relativeTime(ts));

        const lines = str.split("\n").length;
        if (lines > 1)
            parts.push(qsTr("%1 行").arg(lines));

        parts.push(qsTr("%1 字符").arg(str.length));
        return parts.join(" · ");
    }

    // ==================== 操作 ====================
    function copyItem(text) {
        ClipboardService.copyToClipboard(text);
        root.closeRequested();
    }

    function removeItem(text) {
        ClipboardService.removeEntry(text);
    }

    title: qsTr("剪贴板")
    icon: "edit-paste-symbolic"

    // 高度贴着内容走：一两条时不留一大片空白，条数多了封顶后由内部 Flickable 滚动
    windowHeight: Math.round(Math.max(190, Math.min(560, contentHeight + Kirigami.Units.largeSpacing)))

    // 本面板不做搜索：PopupWindow 不是顶层窗口，输入法无法收到按键事件，
    // 搜索框看起来可用却打不出中文，因此只展示历史列表。
    Shortcut {
        sequence: "Escape"
        onActivated: root.closeRequested()
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.now = Date.now()
    }

    // ==================== 历史列表 ====================
    // 沿用 ClipboardService.history（ListModel）：Repeater 会跟随增删重建 delegate，
    // 不需要快照数组。ListModel 的 role 通过 delegate 的 required 属性注入。
    Flickable {
        id: scrollView

        Layout.fillWidth: true
        // 内容少时让 Flickable 收缩，多时封顶，超过时由内部滚动条接管
        Layout.preferredHeight: Math.min(contentHeight, 440)
        visible: ClipboardService.count > 0
        contentWidth: width
        contentHeight: itemsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: listScrollBar

            policy: scrollView.contentHeight > scrollView.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            interactive: true
            implicitWidth: Kirigami.Units.smallSpacing + 6
            padding: 3
            z: 100
            onPressedChanged: {
                if (!pressed && size < 1)
                    scrollView.returnToBounds();

            }

            contentItem: Rectangle {
                implicitWidth: 5
                implicitHeight: Math.min(listScrollBar.available, Math.max(Kirigami.Units.gridUnit * 2, listScrollBar.size * listScrollBar.available))
                radius: implicitWidth / 2
                color: Qt.alpha(Kirigami.Theme.textColor, listScrollBar.pressed ? 0.6 : listScrollBar.hovered ? 0.42 : 0.25)

                Behavior on color {
                    ColorAnimation {
                        duration: Kirigami.Units.shortDuration
                    }

                }

            }

            background: Rectangle {
                radius: 4
                color: Qt.alpha(Kirigami.Theme.backgroundColor, listScrollBar.pressed ? 0.35 : 0)

                Behavior on color {
                    ColorAnimation {
                        duration: Kirigami.Units.shortDuration
                    }

                }

            }

        }

        ColumnLayout {
            id: itemsColumn

            width: scrollView.width
            spacing: Kirigami.Units.mediumSpacing

            Repeater {
                model: ClipboardService.history

                FormCard.FormCard {
                    id: clipCard

                    // ListModel role 注入（与 NotificationWidget 的 required modelData 同模式）
                    required property var clipText
                    required property var time

                    Layout.fillWidth: true

                    FormCard.AbstractFormDelegate {
                        id: clipRow

                        Layout.fillWidth: true
                        onClicked: root.copyItem(clipCard.clipText)

                        // 中键快速删除（类似浏览器的中键关闭标签页）
                        TapHandler {
                            acceptedButtons: Qt.MiddleButton
                            onTapped: root.removeItem(clipCard.clipText)
                        }

                        contentItem: RowLayout {
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                source: root.iconFor(clipCard.clipText)
                                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                implicitHeight: implicitWidth
                                color: clipRow.hovered ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                // 单行 + elide：不使用 wrapMode，避免弹窗首次布局时的换行反馈循环
                                Label {
                                    Layout.fillWidth: true
                                    text: root.preview(clipCard.clipText)
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    color: Kirigami.Theme.textColor
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: root.meta(clipCard.clipText, clipCard.time)
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    font: Kirigami.Theme.smallFont
                                    color: Kirigami.Theme.disabledTextColor
                                }

                            }

                            ToolButton {
                                // 与通知卡片一致：图标顶端对齐
                                Layout.alignment: Qt.AlignTop
                                icon.name: "edit-delete-remove"
                                // 常驻占位、悬停才显现，避免鼠标移入时整行内容左右跳动
                                opacity: clipRow.hovered ? 1 : 0
                                enabled: clipRow.hovered
                                onClicked: root.removeItem(clipCard.clipText)
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("删除此条")

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

        }

    }

    // ==================== 空状态 ====================
    Kirigami.PlaceholderMessage {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Kirigami.Units.largeSpacing * 2
        visible: ClipboardService.count === 0
        icon.name: "edit-paste-symbolic"
        text: qsTr("暂无剪贴板历史")
        explanation: qsTr("复制任意文本后会自动出现在这里。")
    }

    // ==================== head：不随列表滚动的工具 ====================
    // 清空按钮放 head（SlideWindow 的标题栏），滚动时不被带走
    headerTools: ToolButton {
        icon.name: "edit-clear-all"
        enabled: ClipboardService.count > 0
        onClicked: ClipboardService.clearHistory()
        ToolTip.visible: hovered
        ToolTip.text: qsTr("清空历史")
    }

}