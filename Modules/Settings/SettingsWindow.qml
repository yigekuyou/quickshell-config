import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami

// ============================================================================
// 设置窗口：Kirigami.AbstractApplicationWindow，一个真的 xdg toplevel。
//
// 以前这里是 Overlay 层的 PanelWindow + 全屏遮罩，Hyprland 完全管不了：
// 不在 clients 里，不能 focus / 移动 / 归工作区 / 全屏 / 浮动。现在改成一个
// 普通应用窗口，合成器怎么管别的窗口就怎么管它。
//
// 内容直接长在窗口里（没有遮罩、没有居中卡片）：左侧导航 + 右侧页面 +
// 底部配置文件路径；标题栏残留系统的，我们只补一条自己的标题行，同时充当
// 拖动区（拖它 = startSystemMove），保证哪种装饰风格下都能移动窗口。
//
// 打开方式（不变）：
//   qs ipc call settings toggle | open | close | page 1
//   顶栏最左边的齿轮（Modules/Bar/SettingsButton）
//   全局快捷键 quickshell:settings（Services/Shortcuts.qml）
//
// 所有可调参数存在 settings/settings.json，由 Services/Settings.qml 读写；
// 页面只是它的视图，改完立刻生效并去抖落盘。
// ============================================================================
Kirigami.AbstractApplicationWindow {
    id: win

    // ==================== 页面表 ====================
    // 导航和内容都从这里取，加一页 = 加一条 + StackLayout 里加一个页面组件
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
            "icon": "weather-clear",
            "label": qsTr("天气"),
            "component": "WeatherPage.qml"
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
    // IPC 的 page N 需要页数
    readonly property int pageCount: win.pages.length
    property int currentPage: 0

    title: qsTr("Quickshell 设置")
    // Kirigami 默认 visible: true，这里覆盖成跟着开关走
    visible: WidgetState.settingsOpen

    width: Kirigami.Units.gridUnit * 60
    height: Kirigami.Units.gridUnit * 42
    minimumWidth: Kirigami.Units.gridUnit * 42
    minimumHeight: Kirigami.Units.gridUnit * 30

    // 窗口底色和页面里的卡片取同一个来源（Colorscheme），
    // 换配色方案 / 换壁纸色时窗口背景不会和内容对不上
    color: Colorscheme.background


    // Escape 关闭：这里不用 QtQuick.Controls 的 Shortcut。
    // Qt 6.11 的 QQuickShortcut 在对象树被拆掉时会崩：
    //   QQuickShortcut::~QQuickShortcut -> QShortcutMap::removeShortcut -> SEGV
    // 而配置重载（qs ipc call config reload）和每个 "Exiting due to IPC request."
    // 都要整棵拆一次对象树，于是退出/重载必崩（si_code SI_TKILL，见 coredumpctl）。
    // 改挂在内容项上做按键处理：没有全局快捷键注册表要注销，拆树时什么都不用回收。
    // 窗口显示时把焦点收进内容项 —— 窗口里没有 activeFocusItem 的话按键到不了 Keys
    // （原来的 Shortcut 是窗口级注册，不挑焦点，所以这里补一步）
    // Qt.callLater：不能在这里同步 forceActiveFocus —— 窗口刚 map 时同步抢焦点
    // 会把主线程卡在 futex 上，整个 qs 的 IPC 跟着失联。延到下一轮事件循环再抢。
    onVisibleChanged: if (visible) Qt.callLater(contentRoot.forceActiveFocus)

    ColumnLayout {
        id: contentRoot

        anchors.fill: parent
        spacing: 0
        focus: true

        // 子项（导航 ListView、页面里的输入框）没吃掉 Escape 时，事件沿父链冒到这里
        Keys.onEscapePressed: {
            WidgetState.settingsOpen = false;
            event.accepted = true;
        }

        // ---------- 标题栏 ----------
        // 窗口自己有系统标题栏；这条只放标题、关闭按钮，并兼作拖动区。
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

            // 拖动标题栏 = 移动窗口，交给窗口本身的 startSystemMove
            DragHandler {
                target: null
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                onActiveChanged: {
                    if (active)
                        win.startSystemMove();
                }
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
                WeatherPage {}
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

    // ==================== IPC ====================
    // qs ipc call settings toggle / open / close / page N
    IpcHandler {
        target: "settings"

        function toggle(): void {
            WidgetState.settingsOpen = !WidgetState.settingsOpen;
        }

        function open(): void {
            WidgetState.settingsOpen = true;
        }

        function close(): void {
            WidgetState.settingsOpen = false;
        }

        function page(index: int): void {
            win.currentPage = Math.max(0, Math.min(win.pageCount - 1, index));
        }
    }
}
