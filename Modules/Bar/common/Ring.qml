import QtQuick
import QtQuick.Shapes

// 圆形进度环（12 点起顺时针）。
// Qt 文档里 PathAngleArc 就是为「圆形进度指示器」设计的：
//   startAngle 从 3 点方向、顺时针为正，360 = 整圈
// 它能被动画/绑定驱动（不像 Canvas 要手写重绘），也比拿 ConicalGradient 遮罩省事。
//   Ring { progress: 0.42; size: 18; lineWidth: 2; color: ... }
Item {
    id: root

    property real progress: -1          // 0..1；<0 不画
    property real size: 18              // 外径
    property real lineWidth: 2
    property color color: "#ffffff"     // 进度弧颜色
    // 底环：同色低透明度，浓度可调（0 = 只有进度弧，没有整圈底）
    property real trackOpacity: 0.22
    property color trackColor: Qt.alpha(root.color, root.trackOpacity)
    property int capStyle: ShapePath.RoundCap

    implicitWidth: size
    implicitHeight: size
    visible: progress >= 0

    Shape {
        anchors.fill: parent
        // 弧线用 CurveRenderer 才不会有折线感（默认 GeometryRenderer 会把曲线拆成线段）
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.trackColor
            strokeWidth: root.lineWidth
            capStyle: root.capStyle

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: Math.max(0, root.width / 2 - root.lineWidth / 2)
                radiusY: Math.max(0, root.height / 2 - root.lineWidth / 2)
                startAngle: -90
                sweepAngle: 360
            }
        }

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.lineWidth
            capStyle: root.capStyle

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: Math.max(0, root.width / 2 - root.lineWidth / 2)
                radiusY: Math.max(0, root.height / 2 - root.lineWidth / 2)
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, root.progress))
            }
        }
    }
}
