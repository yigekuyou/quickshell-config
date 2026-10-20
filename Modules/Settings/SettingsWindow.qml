import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami

// ============================================================================
// 设置窗口（全屏遮罩 + 居中卡片，左侧导航 / 右侧内容）。
//
// 打开方式（不再占用顶栏）：
//   qs ipc call settings toggle | open | close
//   全局快捷键 quickshell:settings（见 Services/Shortcuts.qml）
//
// 所有可调参数都存在 settings/settings.json，由 Services/Settings.qml 读写；
// 页面只是它的视图，改完立刻生效并去抖落盘。
// ============================================================================
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property var modelData

        // 只在主屏开一份：设置窗口是单例性质的，多屏各来一份会互相抢键盘
        readonly property bool isPrimaryScreen: win.modelData === Quickshell.screens[0]

        visible: WidgetState.settingsOpen && win.isPrimaryScreen
        screen: modelData

        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // ==================== 页面 ====================
        readonly property var pages: [
            {
                "icon": "preferences-desktop-wallpaper",
                "label": qsTr("壁纸")
            },
            {
                "icon": "preferences-desktop-theme",
                "label": qsTr("状态栏")
            },
            {
                "icon": "preferences-desktop-screensaver",
                "label": qsTr("空闲")
            },
            {
                "icon": "help-about",
                "label": qsTr("关于")
            }
        ]
        property int currentPage: 0

        // 不叫 close()：QQuickWindow(QWindow) 自带 close()，重名会被当成覆盖
        function dismiss(): void {
            WidgetState.settingsOpen = false;
        }

        // 打开时把画面抢过来：Escape 关闭，方向键/滚轮都归这里
        Shortcut {
            sequence: "Escape"
            onActivated: win.dismiss()
        }

        // 全局快捷键 quickshell:settings（Hyprland 侧绑 SUPER+S 即可）：
        // 只在主屏那份窗口上处理，否则 N 块屏会切换 N 次
        Connections {
            target: Shortcuts
            enabled: win.isPrimaryScreen

            function onSettingsRequested(): void {
                WidgetState.settingsOpen = !WidgetState.settingsOpen;
            }
        }

        // ==================== 背景遮罩 ====================
        // 点卡片外面关闭。MouseArea 拿独占 grab，卡片自己的 MouseArea 在它上面，
        // 所以点卡片不会连带关掉窗口。
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)

            MouseArea {
                anchors.fill: parent
                onClicked: win.dismiss()
            }
        }

        // ==================== 卡片 ====================
        Kirigami.ShadowedRectangle {
            id: card

            anchors.centerIn: parent
            width: Math.min(parent.width - Kirigami.Units.gridUnit * 3, Kirigami.Units.gridUnit * 62)
            height: Math.min(parent.height - Kirigami.Units.gridUnit * 3, Kirigami.Units.gridUnit * 44)

            color: Kirigami.Theme.backgroundColor
            radius: Sizes.cornerRadius
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
            shadow.size: Kirigami.Units.gridUnit * 1.2
            shadow.yOffset: 6
            shadow.color: Qt.rgba(0, 0, 0, 0.35)

            // 吞掉卡片内的点击，避免穿透到遮罩
            MouseArea {
                anchors.fill: parent
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                // ==================== 左侧导航 ====================
                ColumnLayout {
                    Layout.preferredWidth: Kirigami.Units.gridUnit * 9
                    Layout.fillHeight: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading {
                        text: qsTr("设置")
                        level: 2
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        Layout.bottomMargin: Kirigami.Units.smallSpacing
                    }

                    Repeater {
                        model: win.pages

                        delegate: Item {
                            id: navItem

                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.preferredHeight: Kirigami.Units.gridUnit * 2.1

                            Rectangle {
                                anchors.fill: parent
                                radius: Kirigami.Units.gridUnit * 0.4
                                color: win.currentPage === navItem.index
                                    ? Qt.alpha(Kirigami.Theme.highlightColor, 0.22)
                                    : (navHover.hovered ? Qt.alpha(Kirigami.Theme.textColor, 0.07) : "transparent")

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Kirigami.Units.shortDuration
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Kirigami.Units.smallSpacing
                                    anchors.rightMargin: Kirigami.Units.smallSpacing
                                    spacing: Kirigami.Units.smallSpacing

                                    Kirigami.Icon {
                                        source: navItem.modelData.icon
                                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                        implicitHeight: implicitWidth
                                        color: win.currentPage === navItem.index
                                            ? Kirigami.Theme.highlightColor
                                            : Kirigami.Theme.textColor
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: navItem.modelData.label
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        font.weight: win.currentPage === navItem.index ? Font.DemiBold : Font.Normal
                                        color: win.currentPage === navItem.index
                                            ? Kirigami.Theme.highlightColor
                                            : Kirigami.Theme.textColor
                                    }
                                }
                            }

                            HoverHandler {
                                id: navHover
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: win.currentPage = navItem.index
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    // 配置目录（方便直接去改 json）
                    Label {
                        Layout.fillWidth: true
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        text: "settings.json"
                        font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.6)
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideMiddle
                    }
                }

                Kirigami.Separator {
                    Layout.fillHeight: true
                }

                // ==================== 右侧内容 ====================
                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: win.currentPage

                    WallpaperPage {}
                    BarPage {}
                    IdlePage {}
                    AboutPage {}
                }
            }

            // 右上角关闭
            Item {
                width: Kirigami.Units.gridUnit * 1.8
                height: width
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Kirigami.Units.smallSpacing

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: closeHover.hovered ? Qt.alpha(Kirigami.Theme.negativeTextColor, 0.2) : "transparent"
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    source: "window-close-symbolic"
                    implicitWidth: Kirigami.Units.iconSizes.small
                    implicitHeight: implicitWidth
                    color: Kirigami.Theme.textColor
                }

                HoverHandler {
                    id: closeHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: win.dismiss()
                }
            }
        }

        // ==================== IPC ====================
        // qs ipc call settings toggle / open / close
        IpcHandler {
            target: "settings"
            // 每块屏一份窗口，只让主屏那份注册 IPC，否则 target 会重复
            enabled: win.isPrimaryScreen

            function toggle(): void {
                WidgetState.settingsOpen = !WidgetState.settingsOpen;
            }

            function open(): void {
                WidgetState.settingsOpen = true;
            }

            function close(): void {
                WidgetState.settingsOpen = false;
            }
        }
    }
}