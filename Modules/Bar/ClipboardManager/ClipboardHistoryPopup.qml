import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Services
import qs.Config
import qs.Widget.common
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 剪贴板历史面板。结构与 NetworkWidget / BluetoothWidget / NotificationWidget 保持一致：
// SlideWindow（圆角卡片 + 阴影 + 标题栏）+ FormCard/AbstractFormDelegate 列表。
// 不用 FormButtonDelegate：其内部 Label 是 width: parent.width + wrapMode: Text.Wrap，
// 弹窗从隐藏变为可见时会形成“宽度 -> 换行 -> 隐式高度 -> 布局 -> 宽度”的循环。
SlideWindow {
    id: root
    title: qsTr("剪贴板")
    icon: "edit-paste-symbolic"
    windowHeight: 480

    // 弹窗自己请求关闭（Esc / 选中条目），由调用方把 popupOpen 置 false。
    // 不要直接写 visible = false：visible 通常绑定在外部属性上，赋值会破坏绑定。
    signal closeRequested()

    // 本面板不做搜索：PopupWindow 不是顶层窗口，输入法无法收到按键事件，
    // 搜索框看起来可用却打不出中文，因此只展示历史列表。
    Shortcut {
        sequence: "Escape"
        onActivated: root.closeRequested()
    }

    // 用于刷新“N 分钟前”，只在面板可见时走动，避免后台空转
    property double now: Date.now()
    Timer {
        interval: 30000
        repeat: true
        running: root.visible
        onTriggered: root.now = Date.now()
    }

    // 条目快照（普通数组，交给 Repeater 使用；不要中途改模型引发重排）
    readonly property var items: {
        const out = [];
        const h = ClipboardService.history;
        for (let i = 0; i < h.count; i++) {
            const rec = h.get(i);
            out.push({ "text": rec.clipText, "time": rec.time });
        }
        return out;
    }

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

    function meta(item) {
        const text = String(item.text);
        const parts = [];
        if (item.time > 0)
            parts.push(root.relativeTime(item.time));
        const lines = text.split("\n").length;
        if (lines > 1)
            parts.push(qsTr("%1 行").arg(lines));
        parts.push(qsTr("%1 字符").arg(text.length));
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

    // ==================== 标题栏工具 ====================
    headerTools: ToolButton {
        icon.name: "edit-clear-all"
        enabled: ClipboardService.count > 0
        onClicked: ClipboardService.clearHistory()
        ToolTip.visible: hovered
        ToolTip.text: qsTr("清空历史")
    }

    // ==================== 历史列表 ====================
    Repeater {
        model: root.items

        FormCard.FormCard {
            id: clipCard
            Layout.fillWidth: true
            // Repeater 注入的 modelData 提升到 FormCard 上，
            // 内层 AbstractFormDelegate 不再声明 required property modelData。
            property var itemData: modelData

            FormCard.AbstractFormDelegate {
                id: clipRow
                Layout.fillWidth: true
                onClicked: root.copyItem(clipCard.itemData.text)

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: root.iconFor(clipCard.itemData.text)
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
                            text: root.preview(clipCard.itemData.text)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            color: Kirigami.Theme.textColor
                        }
                        Label {
                            Layout.fillWidth: true
                            text: root.meta(clipCard.itemData)
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font: Kirigami.Theme.smallFont
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

                    ToolButton {
                        icon.name: "edit-delete-remove"
                        // 常驻占位、悬停才显现，避免鼠标移入时整行内容左右跳动
                        opacity: clipRow.hovered ? 1 : 0
                        enabled: clipRow.hovered
                        onClicked: root.removeItem(clipCard.itemData.text)
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("删除此条")
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Kirigami.Units.shortDuration
                            }
                        }
                    }
                }

                // 中键快速删除（类似浏览器的中键关闭标签页）
                TapHandler {
                    acceptedButtons: Qt.MiddleButton
                    onTapped: root.removeItem(clipCard.itemData.text)
                }
            }
        }
    }

    // ==================== 空状态 ====================
    Kirigami.PlaceholderMessage {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Kirigami.Units.largeSpacing * 2
        visible: root.items.length === 0
        icon.name: "edit-paste-symbolic"
        text: qsTr("暂无剪贴板历史")
        explanation: qsTr("复制任意文本后会自动出现在这里。")
    }
}
