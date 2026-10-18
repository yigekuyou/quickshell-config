import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami

// 应用启动器：从顶栏下方弹出的搜索面板。
//
// 用 PanelWindow + keyboardFocus: Exclusive 而不是 PopupWindow，因为非顶层窗口
// 在 Wayland 下收不到输入法事件（中文打不进去）。窗口只在需要时创建一次，
// 之后靠 openLauncher() / closeLauncher() 显示隐藏。
PanelWindow {
    id: root

    visible: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    // 只有显示时才抢键盘焦点，隐藏时把焦点还给原来的窗口
    WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
    }
    // 面板宽度：最多 40 个网格单位（约 720px），窄屏时占屏幕一半
    readonly property real cardWidth: Math.min(Kirigami.Units.gridUnit * 40, Math.round(screen.width * 0.46))
    margins {
        top: Sizes.barHeight + Kirigami.Units.smallSpacing * 3
        left: Math.round((screen.width - cardWidth) / 2)
        right: Math.round((screen.width - cardWidth) / 2)
    }

    // 列表高度按整行算：结果少的时候窗口自己变矮，结果多时最多 6 行，
    // 而且底部不会露出半行。
    readonly property real rowHeight: Kirigami.Units.gridUnit * 2.6
    readonly property int visibleRows: resultsList.count > 0 ? Math.min(resultsList.count, 6) : 3
    readonly property real listHeight: visibleRows * rowHeight
    implicitHeight: Math.round(Kirigami.Units.gridUnit * 4.4 + listHeight)

    // 窗口映射完成后再抢焦点，否则 surface 还没就绪，输入框拿不到键盘
    onVisibleChanged: {
        if (visible)
            Qt.callLater(() => searchInput.forceActiveFocus());
    }

    function pickScreen() {
        try {
            const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
            for (const s of Quickshell.screens) {
                if (s.name === name)
                    return s;
            }
        } catch (e) {
            // 非 Hyprland 会话：退回第一块屏
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    function openLauncher() {
        root.screen = root.pickScreen();
        searchInput.text = "";
        LauncherService.searchText = "";
        resultsList.currentIndex = 0;
        root.visible = true;
        Qt.callLater(() => {
            if (root.visible) {
                searchInput.forceActiveFocus();
                resultsList.positionViewAtBeginning();
            }
        });
    }

    function closeLauncher() {
        if (!root.visible)
            return;
        searchInput.text = "";
        LauncherService.searchText = "";
        root.visible = false;
    }

    function toggleLauncher() {
        if (root.visible)
            root.closeLauncher();
        else
            root.openLauncher();
    }

    function launchCurrent() {
        const entry = LauncherService.model.values[resultsList.currentIndex];
        if (!entry)
            return;
        LauncherService.launchEntry(entry);
        root.closeLauncher();
    }

    Kirigami.ShadowedRectangle {
        anchors.fill: parent
        radius: Kirigami.Units.gridUnit * 0.7
        // 启动器是模态界面，用不透明底色，避免背后窗口的文字透出来干扰阅读
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Qt.alpha(Kirigami.Theme.focusColor, 0.35)
        shadow.color: Qt.rgba(0, 0, 0, 0.35)
        shadow.size: 24
        shadow.yOffset: 6

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.SearchField {
                id: searchInput
                Layout.fillWidth: true
                placeholderText: qsTr("搜索应用…")
                focus: true

                onTextChanged: {
                    resultsList.currentIndex = 0;
                    LauncherService.searchText = text;
                }

                Keys.onPressed: (event) => {
                    switch (event.key) {
                    case Qt.Key_Down:
                        resultsList.incrementCurrentIndex();
                        event.accepted = true;
                        break;
                    case Qt.Key_Up:
                        resultsList.decrementCurrentIndex();
                        event.accepted = true;
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        root.launchCurrent();
                        event.accepted = true;
                        break;
                    case Qt.Key_Escape:
                        root.closeLauncher();
                        event.accepted = true;
                        break;
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                visible: resultsList.count > 0
                opacity: 0.5
            }

            ListView {
                id: resultsList
                Layout.fillWidth: true
                Layout.preferredHeight: root.listHeight
                // 没有结果时让位给下面的占位提示，否则两个都占高度会把窗口撑成两倍
                visible: count > 0
                clip: true
                model: LauncherService.model
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: 0

                ScrollBar.vertical: ScrollBar {
                    policy: resultsList.contentHeight > resultsList.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                delegate: ItemDelegate {
                    id: resultItem
                    required property var modelData
                    required property int index

                    width: resultsList.width
                    height: root.rowHeight
                    padding: Kirigami.Units.smallSpacing
                    highlighted: ListView.isCurrentItem
                    hoverEnabled: true

                    onClicked: {
                        LauncherService.launchEntry(resultItem.modelData);
                        root.closeLauncher();
                    }

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing * 0.6

                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                            source: resultItem.modelData.icon || "application-x-executable"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Label {
                                Layout.fillWidth: true
                                text: resultItem.modelData.name
                                elide: Text.ElideRight
                                color: resultItem.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                font: Kirigami.Theme.defaultFont
                            }

                            Label {
                                Layout.fillWidth: true
                                // 很多 .desktop 的 GenericName 跟 Name 一模一样，重复显示没意义
                                readonly property string subtitle: (resultItem.modelData.genericName || resultItem.modelData.comment || "").replace(/\s+/g, " ").trim()
                                visible: subtitle !== "" && subtitle.toLowerCase() !== resultItem.modelData.name.toLowerCase()
                                text: subtitle
                                elide: Text.ElideRight
                                opacity: 0.7
                                font: Kirigami.Theme.smallFont
                                color: resultItem.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                            }
                        }
                    }

                    background: Rectangle {
                        radius: Kirigami.Units.smallSpacing
                        color: resultItem.highlighted
                            ? Qt.alpha(Kirigami.Theme.highlightColor, 0.4)
                            : resultItem.hovered
                                ? Qt.alpha(Kirigami.Theme.highlightColor, 0.16)
                                : "transparent"
                    }
                }
            }

            // 没有结果时的占位提示
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.listHeight
                visible: resultsList.count === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Kirigami.Units.iconSizes.large
                        Layout.preferredHeight: Kirigami.Units.iconSizes.large
                        source: "edit-find-symbolic"
                        opacity: 0.45
                    }

                    Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("没有找到匹配的应用")
                        opacity: 0.6
                    }
                }
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("↑↓ 选择 · Enter 打开 · Esc 关闭")
                horizontalAlignment: Text.AlignHCenter
                opacity: 0.45
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.textColor
            }
        }
    }
}
