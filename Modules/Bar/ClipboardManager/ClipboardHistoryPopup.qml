import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Services
import qs.Config
import org.kde.kirigami as Kirigami

PopupWindow {
    id: popup
    visible: true
    color: "transparent"
    mask: null

    implicitWidth: Kirigami.Units.gridUnit * 26
    implicitHeight: content.implicitHeight + Kirigami.Units.smallSpacing

    signal closeRequested()

    // 点击弹窗外部自动关闭并把 visible 置 false
    grabFocus: true

    // 锚定到顶栏左栏（ClipboardStatus 所在侧）
    anchor.window: barWindow
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Bottom
    anchor.margins.top: Kirigami.Units.smallSpacing * 2

    Kirigami.ShadowedRectangle {
        id: card
        anchors.fill: parent
        radius: Kirigami.Units.largeSpacing
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
        shadow.size: Kirigami.Units.smallSpacing
        shadow.color: Qt.rgba(0, 0, 0, 0.3)
        shadow.yOffset: 2

        ColumnLayout {
            id: content
            anchors.fill: parent
            spacing: 0

            // 头部：标题 + 计数 + 清空
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.smallSpacing
                Layout.topMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    level: 5
                    opacity: 0.7
                    text: qsTr("剪贴板历史 (%1)").arg(ClipboardService.count)
                }
                Item {
                    Layout.fillWidth: true
                }
                Button {
                    flat: true
                    text: qsTr("清空")
                    icon.name: "edit-clear-all"
                    enabled: ClipboardService.count > 0
                    onClicked: {
                        ClipboardService.clearHistory()
                        popup.refresh()
                    }
                    contentItem: RowLayout {
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            source: "edit-clear-all"
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: implicitWidth
                            color: Kirigami.Theme.textColor
                        }
                        Kirigami.Heading {
                            level: 5
                            text: qsTr("清空")
                        }
                    }
                }
            }

            // 搜索框
            TextField {
                id: searchField
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                placeholderText: qsTr("搜索…")
                onTextEdited: popup.refresh()
                Keys.onEscapePressed: popup.close()
            }

            // 历史列表（搜索过滤代理）
            ListView {
                id: listView
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, Kirigami.Units.gridUnit * 28)
                Layout.bottomMargin: Kirigami.Units.smallSpacing
                clip: true
                model: filtered
                delegate: ItemDelegate {
                    id: entry
                    required property string clipText

                    width: ListView.view.width
                    implicitHeight: Math.max(Kirigami.Units.gridUnit * 1.6, entryLayout.implicitHeight)

                    text: (clipText.length > 90 ? clipText.substring(0, 90) + "…" : clipText.replace(/\n/g, " "))
                    onClicked: {
                        ClipboardService.copyToClipboard(clipText)
                        popup.close()
                    }

                    contentItem: RowLayout {
                        id: entryLayout
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: "edit-paste-symbolic"
                            color: Kirigami.Theme.disabledTextColor
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: implicitWidth
                        }
                        Text {
                            Layout.fillWidth: true
                            text: entry.text
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            color: Kirigami.Theme.textColor
                            font.family: Kirigami.Theme.defaultFont.family
                        }
                        ToolButton {
                            icon.name: "window-close"
                            flat: true
                            implicitWidth: Kirigami.Units.iconSizes.small
                            implicitHeight: implicitWidth
                            onClicked: {
                                ClipboardService.removeEntry(entry.clipText)
                                popup.refresh()
                            }
                        }
                    }
                }

                // 空态
                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    visible: listView.count === 0
                    icon.name: "edit-paste-symbolic"
                    text: qsTr("暂无历史记录")
                }
            }
        }
    }

    ListModel {
        id: filtered
    }

    function refresh() {
        filtered.clear()
        const q = searchField.text.toLowerCase()
        for (let i = 0; i < ClipboardService.history.count; i++) {
            const t = ClipboardService.history.get(i).clipText
            if (q === "" || t.toLowerCase().indexOf(q) !== -1)
                filtered.append({
                    "clipText": t
                })
        }
    }

    Connections {
        target: ClipboardService
        function onHistoryUpdated() {
            popup.refresh()
        }
    }

    Component.onCompleted: {
        popup.refresh()
        searchField.forceActiveFocus()
    }

    function close() {
        popup.visible = false
        popup.closeRequested()
    }
}
