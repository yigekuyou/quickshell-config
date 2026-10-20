import org.kde.kirigami as Kirigami
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Services

// 底部面板的运行中应用托盘。
//
// 每个应用一个方块按钮：悬停高亮、按下缩一下，当前有焦点窗口的应用在底部
// 显示一条主题色短横线。图标与名字都来自 .desktop 条目
// （见 Services/TaskbarApps.qml），没有 .desktop 的窗口才退回 appId。
Kirigami.ShadowedRectangle {
    id: root

    // 没有运行中的应用时整块收起来，面板只留启动器按钮
    visible: TaskbarApps.apps.length > 0

    readonly property real buttonSize: Kirigami.Units.gridUnit * 1.35
    readonly property real iconSize: Kirigami.Units.gridUnit * 1.1

    implicitWidth: row.implicitWidth + Kirigami.Units.smallSpacing * 2
    implicitHeight: Sizes.barHeight - Kirigami.Units.smallSpacing

    radius: Sizes.cornerRadius
    color: Qt.alpha(Kirigami.Theme.textColor, 0.035)
    border.width: 1
    // Kirigami.Theme 里没有 dividerColor（读到 undefined，会刷 Unable to assign [undefined] to QColor）
    border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
    shadow.color: Qt.rgba(0, 0, 0, 0)
    shadow.size: 0

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing / 2

        Repeater {
            model: TaskbarApps.apps

            delegate: Item {
                id: button
                required property var modelData

                readonly property bool activeWindow: modelData.active
                readonly property bool hovered: hoverHandler.hovered

                Layout.alignment: Qt.AlignVCenter
                implicitWidth: root.buttonSize
                implicitHeight: root.buttonSize

                // 悬停 / 当前窗口 的底色
                Rectangle {
                    anchors.fill: parent
                    radius: Kirigami.Units.smallSpacing
                    color: button.hovered
                        ? Qt.alpha(Kirigami.Theme.highlightColor, 0.28)
                        : button.activeWindow
                            ? Qt.alpha(Kirigami.Theme.highlightColor, 0.14)
                            : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                }

                Kirigami.Icon {
                    id: appIcon
                    anchors.centerIn: parent
                    width: root.iconSize
                    height: root.iconSize
                    source: button.modelData.iconName

                    scale: tapHandler.pressed ? 0.88 : button.hovered ? 1.08 : 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // 当前有焦点窗口的指示条。托盘里的应用本来都在运行，
                // 每个图标下面再点一个小圆点只会显得很吵，所以只标“当前窗口”。
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                    height: 2.5
                    radius: height / 2
                    width: root.buttonSize * 0.45
                    color: Kirigami.Theme.highlightColor
                    opacity: button.activeWindow ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                }

                HoverHandler {
                    id: hoverHandler
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: tapHandler
                    acceptedButtons: Qt.LeftButton
                    onTapped: root.activateApp(button.modelData)
                }


            }
        }
    }

    // 点击托盘图标：有焦点窗口就切到下一个窗口，只有一个窗口则最小化；
    // 没有焦点窗口时恢复第一个（顺手取消最小化）。
    function activateApp(app) {
        const wins = app.toplevels;
        if (!wins || wins.length === 0)
            return;

        let activeIndex = -1;
        for (let i = 0; i < wins.length; i++) {
            if (wins[i].activated) {
                activeIndex = i;
                break;
            }
        }

        if (activeIndex === -1) {
            wins[0].activate();
            if (wins[0].minimized)
                wins[0].minimized = false;
            return;
        }

        if (wins.length === 1) {
            wins[0].minimized = true;
            return;
        }

        const next = wins[(activeIndex + 1) % wins.length];
        next.activate();
        if (next.minimized)
            next.minimized = false;
    }
}
