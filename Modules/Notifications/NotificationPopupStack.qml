import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami

// 屏幕右上角的一摞通知弹窗。
//
// 为什么是一个窗口而不是每张通知一个窗口：
//  - Wayland 下每张通知都开一个 layer-shell 表面，位置只能靠 margins 手算，
//    某张卡片正文换行、高度变化后位置就全乱（旧实现就是 index * implicitHeight）；
//  - PopupWindow 必须有父窗口，脱离 Wallpaper/Notif.qml 那个独立进程后
//    没有可锚的 barWindow，直接报错。
// 现在：一个 Overlay 层表面，宽度固定，高度跟着内容走；卡片用 ListView 管理，
// 进出场和位移交给 add/remove/displaced 过渡，不需要手动 destroy()。
PanelWindow {
    id: root

    readonly property int cardWidth: Kirigami.Units.gridUnit * 21

    color: "transparent"

    WlrLayershell.namespace: "quickshell-notification"
    WlrLayershell.layer: WlrLayer.Overlay
    // 不抢键盘/输入法焦点；通知不需要打字
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }
    margins {
        top: Sizes.barHeight + Kirigami.Units.smallSpacing * 2
        right: Kirigami.Units.smallSpacing * 2
    }

    implicitWidth: cardWidth
    implicitHeight: list.contentHeight

    // 没有弹窗时把表面整个收掉，不留 0 高度的空 surface
    // 全屏时也收掉（通知仍在队列里，退出全屏后照常弹出）
    visible: NotificationManager.hasPopups && !FullscreenState.covers(root.screen)

    // 跟随当前聚焦的显示器；非 Hyprland 会话退回第一块屏
    function pickScreen() {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        for (const s of Quickshell.screens) {
            if (s.name === name)
                return s;
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    onVisibleChanged: {
        if (visible)
            root.screen = root.pickScreen();
    }

    ListView {
        id: list

        width: parent.width
        // 高度等于内容高度：这摞窗口不需要滚动
        height: contentHeight
        model: NotificationManager.popups
        spacing: Kirigami.Units.smallSpacing
        interactive: false
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 0

        // NotificationPopup 自己声明了 required property var modelData，
        // 由 ListView 注入；不要在这里写 notification: modelData
        delegate: NotificationPopup {
            width: list.width
        }

        add: Transition {
            ParallelAnimation {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Kirigami.Units.shortDuration
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    property: "scale"
                    from: 0.96
                    to: 1
                    duration: Kirigami.Units.longDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Kirigami.Units.shortDuration
            }
        }

        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: Kirigami.Units.longDuration
                easing.type: Easing.OutCubic
            }
        }
    }
}
