import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
import Quickshell.WindowManager

// 工作区指示器。
// 原来是「地球图标 + 叠在上面的数字」，图标本身占地方、数字还压在图形上不好读。
// 现在每个工作区就是一个圆角小胶囊，里面只有数字：
//   · 密集：去掉图标底图，胶囊宽度只跟数字走，间距取「左侧 → 按钮间距」
//   · 可读：数字单独居中、无叠加；当前工作区用强调色实心 + 反色数字，其余用低透明度
Kirigami.ShadowedRectangle {
    id: root

    color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.5)
    radius: Sizes.cornerRadius
    implicitHeight: Sizes.barHeight
    implicitWidth: layout.implicitWidth + Sizes.secPad("left") * 2

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Math.max(1, Math.round(Sizes.secGap("left")))

        Repeater {
            model: WindowManager.windowsets.reduce((max, w) =>
                Math.max(max, w.coordinates[0]), -Infinity)

            delegate: Rectangle {
                id: pill

                readonly property var ws: WindowManager.windowsets.find(w => w.coordinates.includes(index + 1))
                readonly property bool active: ws ? ws.active : false
                readonly property bool occupied: ws !== undefined

                implicitHeight: Math.round(Sizes.secIcon("left") * 1.4)
                implicitWidth: Math.max(implicitHeight, numText.implicitWidth + Math.round(implicitHeight * 0.45))
                radius: height / 2

                color: pill.active ? Kirigami.Theme.highlightColor
                    : (pill.occupied ? Qt.alpha(Kirigami.Theme.textColor, 0.14) : "transparent")
                border.width: (pill.active || pill.occupied) ? 0 : 1
                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.18)

                Behavior on color {
                    ColorAnimation { duration: Kirigami.Units.shortDuration }
                }

                HoverHandler {
                    enabled: pill.ws ? pill.ws.canActivate : false
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        if (pill.ws && pill.ws.canActivate)
                            pill.ws.activate();
                    }
                }

                Label {
                    id: numText

                    anchors.centerIn: parent
                    text: pill.ws ? pill.ws.coordinates[0] : ""
                    font.pixelSize: Math.round(pill.implicitHeight * 0.6)
                    font.weight: pill.active ? Font.DemiBold : Font.Normal
                    color: pill.active ? Kirigami.Theme.backgroundColor
                        : (pill.occupied ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor)
                }
            }
        }
    }
}
