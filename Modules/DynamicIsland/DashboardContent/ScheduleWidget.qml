import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Services
import org.kde.kirigami as Kirigami

// 课表 —— 颜色与尺寸全部来自 Kirigami.Theme / Kirigami.Units，
// 视觉语言与 ClockContent / MediaContent 统一。
Item {
    id: root

    property var scheduleItems: []
    property var timeHeaders: []
    property var headers: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    // 所有固定尺寸由 Kirigami.Units 派生，跟随系统字号缩放
    readonly property int timeW: Kirigami.Units.gridUnit * 2.5       // 左侧时间列宽
    readonly property int cellW: Kirigami.Units.gridUnit * 3         // 单元格宽
    readonly property int cellH: Kirigami.Units.gridUnit * 3         // 单元格高
    readonly property int headerH: Kirigami.Units.gridUnit * 1.4     // 表头高
    readonly property int gridSpacing: Kirigami.Units.largeSpacing   // 网格间距

    // ==========================================
    // 纯粹的 ID 映射引擎 (主题色派生的 8 色调色板)
    // ==========================================
    // 前 4 个：Kirigami 主题的中性/强调容器色；后 4 个：相同色相压低透明度
    readonly property var cellColors: [
        Kirigami.Theme.alternateBackgroundColor,
        Qt.alpha(Kirigami.Theme.highlightColor, 0.30),
        Qt.alpha(Kirigami.Theme.negativeTextColor, 0.30),
        Qt.alpha(Kirigami.Theme.positiveTextColor, 0.30),
        Qt.alpha(Kirigami.Theme.neutralTextColor, 0.30),
        Qt.alpha(Kirigami.Theme.textColor, 0.16),
        Qt.alpha(Kirigami.Theme.highlightColor, 0.18),
        Qt.alpha(Kirigami.Theme.textColor, 0.10)
    ]

    // 文字色：前 4 个用主题前景色，后 4 个用对应色相的亮色，保证可读
    readonly property var cellTextColors: [
        Kirigami.Theme.textColor,
        Kirigami.Theme.highlightColor,
        Kirigami.Theme.negativeTextColor,
        Kirigami.Theme.positiveTextColor,
        Kirigami.Theme.neutralTextColor,
        Kirigami.Theme.textColor,
        Kirigami.Theme.highlightColor,
        Kirigami.Theme.textColor
    ]

    function getColorById(id) {
        return root.cellColors[id % root.cellColors.length]  // 无限循环轮询
    }

    function getTextColorById(id) {
        return root.cellTextColors[id % root.cellTextColors.length]
    }

    // ==========================================
    // 安全缓冲区 JSON 读取引擎
    // ==========================================
    property string jsonBuffer: ""

    Process {
        id: scheduleLoader
        // 路径统一由 Services/Directories 提供
        command: ["cat", Directories.scheduleCacheFile]
        running: false
        stdout: SplitParser {
            onRead: (data) => { root.jsonBuffer += data; }
        }
        onExited: {
            try {
                if (root.jsonBuffer.trim() !== "") {
                    let parsed = JSON.parse(root.jsonBuffer);
                    root.timeHeaders = parsed.timeHeaders || [];
                    root.scheduleItems = parsed.scheduleItems || [];
                }
            } catch(e) { console.log("课表 JSON 解析错误:", e); }
            root.jsonBuffer = "";
        }
    }

    Component.onCompleted: scheduleLoader.running = true
    onVisibleChanged: {
        if (visible) {
            scheduleLoader.running = false;
            scheduleLoader.running = true;
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing * 1.5

        // 【象限 1：左上角 (点击手动刷新)】
        Item {
            x: 0; y: 0
            width: root.timeW; height: root.headerH
            Label {
                anchors.centerIn: parent
                text: "Time"
                color: Kirigami.Theme.textColor
                opacity: 0.7
                font.family: Kirigami.Theme.smallFont.family
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.weight: Font.Bold
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.scheduleLoader.running = false;
                    root.scheduleLoader.running = true;
                }
            }
        }

        // 【象限 2：顶部表头】
        Item {
            x: root.timeW + root.gridSpacing
            y: 0
            width: parent.width - x; height: root.headerH
            clip: true
            Row {
                x: -scheduleScroll.contentItem.contentX
                spacing: root.gridSpacing
                Repeater {
                    model: root.headers
                    Item {
                        width: root.cellW; height: root.headerH
                        Label {
                            anchors.centerIn: parent
                            text: modelData
                            color: Kirigami.Theme.textColor
                            opacity: 0.7
                            font.family: Kirigami.Theme.smallFont.family
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }

        // 【象限 3：左侧时间列】
        Item {
            x: 0
            y: root.headerH + root.gridSpacing
            width: root.timeW; height: parent.height - y
            clip: true
            Column {
                y: -scheduleScroll.contentItem.contentY
                spacing: root.gridSpacing
                Repeater {
                    model: root.timeHeaders
                    Item {
                        width: root.timeW; height: root.cellH
                        Label {
                            anchors.centerIn: parent
                            text: modelData.replace(" - ", "\n")
                            color: Kirigami.Theme.textColor
                            opacity: 0.5
                            font.family: Kirigami.Theme.smallFont.family
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        // 【象限 4：主体课程网格】
        ScrollView {
            id: scheduleScroll
            x: root.timeW + root.gridSpacing
            y: root.headerH + root.gridSpacing
            width: parent.width - x
            height: parent.height - y
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            GridLayout {
                width: implicitWidth
                height: implicitHeight
                columns: 7
                rowSpacing: root.gridSpacing; columnSpacing: root.gridSpacing

                Repeater {
                    model: root.scheduleItems
                    Rectangle {
                        Layout.row: modelData.row; Layout.column: modelData.col; Layout.rowSpan: modelData.rowSpan
                        Layout.preferredWidth: root.cellW; Layout.preferredHeight: root.cellH
                        Layout.fillWidth: true; Layout.fillHeight: true
                        radius: Kirigami.Units.gridUnit * 0.4

                        // 彻底抛弃名字计算，直接通过 Python 传入的 ID 调用颜色
                        color: modelData.isEmpty ? "transparent" : root.getColorById(modelData.colorId)
                        border.width: modelData.isEmpty ? 1 : 0
                        // 与 DynamicIsland 外框同款的细腻描边
                        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.15)

                        Label {
                            anchors.fill: parent; anchors.margins: Kirigami.Units.smallSpacing / 2
                            text: modelData.text.replace(" (", "\n(").replace("（", "\n（")
                            color: modelData.isEmpty
                                   ? Qt.alpha(Kirigami.Theme.textColor, 0.7)
                                   : root.getTextColorById(modelData.colorId)
                            font.family: Kirigami.Theme.smallFont.family
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                            font.weight: modelData.isEmpty ? Font.Normal : Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // 【右键拖拽逻辑】
        MouseArea {
            x: root.timeW + root.gridSpacing; y: root.headerH + root.gridSpacing
            width: parent.width - x; height: parent.height - y
            acceptedButtons: Qt.RightButton
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.ArrowCursor

            property real startX: 0; property real startY: 0
            property real startContentX: 0; property real startContentY: 0

            onPressed: (mouse) => {
                startX = mouse.x; startY = mouse.y
                startContentX = scheduleScroll.contentItem.contentX
                startContentY = scheduleScroll.contentItem.contentY
            }

            onPositionChanged: (mouse) => {
                if (pressed) {
                    let flickable = scheduleScroll.contentItem;
                    let targetX = startContentX - (mouse.x - startX);
                    let targetY = startContentY - (mouse.y - startY);

                    let maxX = Math.max(0, flickable.contentWidth - scheduleScroll.width);
                    let maxY = Math.max(0, flickable.contentHeight - scheduleScroll.height);

                    flickable.contentX = Math.max(0, Math.min(targetX, maxX));
                    flickable.contentY = Math.max(0, Math.min(targetY, maxY));
                }
            }
        }
    }
}
