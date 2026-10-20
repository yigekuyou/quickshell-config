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
// 设置窗口（全屏遮罩 + 居中卡片：顶部标题栏 / 左侧导航 / 右侧内容）。
//
// 全部用标准组件搭：ListView + ItemDelegate 做导航、ToolButton 做关闭、
// StackLayout 做翻页、Kirigami.Separator 做分隔线。没有手画的悬停高亮/
// 自绘点击区，交互行为都来自 QtQuick.Controls 自己的实现。
//
// 打开方式（不占用顶栏）：
//   qs ipc call settings toggle | open | close
//   顶栏最左边的齿轮（Modules/Bar/SettingsButton）
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

        // ==================== 页面表 ====================
        // 导航和内容都从这里取，加一页 = 加一条 + 加一个页面组件
        readonly property var pages: [
            {
                "icon": "preferences-desktop-wallpaper",
                "label": qsTr("壁纸"),
                "component": "WallpaperPage.qml"
            },
            {
                "icon": "preferences-desktop-theme",
                "label": qsTr("状态栏"),
                "component": "BarPage.qml"
            },
            {
                "icon": "preferences-desktop-effects",
                "label": qsTr("灵动岛"),
                "component": "IslandPage.qml"
            },
            {
                "icon": "preferences-system-symbolic",
                "label": qsTr("托盘"),
                "component": "TrayPage.qml"
            },
            {
                "icon": "preferences-desktop-screensaver",
                "label": qsTr("空闲"),
                "component": "IdlePage.qml"
            },
            {
                "icon": "help-about",
                "label": qsTr("关于"),
                "component": "AboutPage.qml"
            }
        ]
        property int currentPage: 0

        // 不叫 close()：QQuickWindow(QWindow) 自带 close()，重名会被当成覆盖
        function dismiss(): void {
            WidgetState.settingsOpen = false;
        }

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

        // ==================== 遮罩 ====================
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.4)

            MouseArea {
                anchors.fill: parent
                onClicked: win.dismiss()
            }
        }

        // ==================== 卡片 ====================
        Kirigami.ShadowedRectangle {
            id: card

            anchors.centerIn: parent
            width: Math.min(parent.width - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 60)
            height: Math.min(parent.height - Kirigami.Units.gridUnit * 4, Kirigami.Units.gridUnit * 42)

            color: Kirigami.Theme.backgroundColor
            radius: Kirigami.Units.gridUnit * 0.6
            border.width: 1
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
            shadow.size: Kirigami.Units.gridUnit * 1.2
            shadow.yOffset: 6
            shadow.color: Qt.rgba(0, 0, 0, 0.35)

            // 卡片自己的空白处吞掉点击（别穿透到遮罩把窗口关了）。
            // 声明在最前面 → 始终在所有内容下面，不会挡住控件。
            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // ---------- 标题栏 ----------
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading {
                        text: qsTr("设置")
                        level: 2
                        Layout.fillWidth: true
                    }

                    ToolButton {
                        icon.name: "window-close"
                        display: AbstractButton.IconOnly
                        flat: true
                        onClicked: win.dismiss()
                        ToolTip.visible: hovered
                        ToolTip.text: qsTr("关闭 (Esc)")
                        ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                // ---------- 主体 ----------
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // 左侧导航
                    ListView {
                        id: navList

                        Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                        Layout.fillHeight: true
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        Layout.rightMargin: Kirigami.Units.smallSpacing
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        Layout.bottomMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing
                        clip: true
                        model: win.pages
                        currentIndex: win.currentPage

                        delegate: ItemDelegate {
                            id: navDelegate

                            required property var modelData
                            required property int index

                            width: ListView.view.width
                            implicitHeight: Kirigami.Units.gridUnit * 2
                            text: navDelegate.modelData.label
                            icon.name: navDelegate.modelData.icon
                            highlighted: win.currentPage === navDelegate.index
                            onClicked: win.currentPage = navDelegate.index
                        }

                        // 键盘上下键也能换页
                        Keys.onUpPressed: win.currentPage = Math.max(0, win.currentPage - 1)
                        Keys.onDownPressed: win.currentPage = Math.min(win.pages.length - 1, win.currentPage + 1)
                    }

                    // 竖分隔线：Separator 没有 orientation，靠 1px 宽 + 撑满高度成竖线
                    Kirigami.Separator {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                    }

                    // 右侧内容
                    StackLayout {
                        id: pageStack
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: Kirigami.Units.largeSpacing
                        currentIndex: win.currentPage

                        WallpaperPage {}
                        BarPage {}
                        IslandPage {}
                        TrayPage {}
                        IdlePage {}
                        AboutPage {}
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                // ---------- 底栏：配置文件路径 ----------
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Kirigami.Units.largeSpacing
                    Layout.rightMargin: Kirigami.Units.largeSpacing
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    Layout.bottomMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        source: "document-open-folder"
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: implicitWidth
                        color: Kirigami.Theme.disabledTextColor
                    }

                    Label {
                        Layout.fillWidth: true
                        text: Settings.path
                        elide: Text.ElideMiddle
                        font: Kirigami.Theme.smallFont
                        color: Kirigami.Theme.disabledTextColor

                        TapHandler {
                            onTapped: Qt.openUrlExternally("file://" + Settings.path)
                        }
                    }
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

            // qs ipc call settings page 0   -> 切到指定页（0 壁纸 1 状态栏 2 空闲 3 关于）
        function page(index: int): void {
            win.currentPage = Math.max(0, Math.min(win.pages.length - 1, index));
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