import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Config
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar

// 日历 —— 数据后端是 KDE Plasma 的日历组件，外观与
// ClockContent / MediaContent 统一（Kirigami 组件 + Theme 配色 + Units 尺寸）。
// ------------------------------------------------------------------
//   * PlasmaCalendar.Calendar        —— 42 格月历数据模型 + 月份导航
//   * PlasmaCalendar.EventPluginsManager
//       - "holidaysevents"     KHolidays 法定节假日（区域取自
//                              ~/.config/plasma_calendar_holiday_regions）
//       - "alternatecalendar"  农历日名（Chinese 历法，
//                              ~/.config/plasma_calendar_alternatecalendar）
Item {
    id: root

    // 真实的“今天”，跨天后自动刷新
    property date today: new Date()
    // 当前选中的日期（底部显示它当天的节假日）
    property date selectedDate: new Date()
    // 选中日期的事件（节假日插件异步返回，到达后刷新）
    property var selectedEvents: []

    // 是否正在显示“今天”所在的月份（不是的话顶部给一个「今」快捷按钮）
    readonly property bool showingCurrentMonth: cal.year === root.today.getFullYear()
                                                && cal.month === root.today.getMonth() + 1

    function refreshSelectedEvents() {
        // DaysModel::eventsForDate() 内部带缓存（lastRequestedAgendaDate），
        // 而且只有在「本次数据包含真实今天」时才会失效。节假日数据是插件异步
        // 返回的：若在数据到达前查询，空结果会被缓存住，之后永远拿到空列表。
        // 所以先用一个哨兵日期把缓存「顶掉」，再查真正选中的日期，
        // 保证每次都读到最新的 eventsData。
        cal.daysModel.eventsForDate(new Date(1970, 0, 1))
        root.selectedEvents = cal.daysModel.eventsForDate(root.selectedDate)
    }

    onSelectedDateChanged: refreshSelectedEvents()

    // ---------------- Plasma 日历数据后端 ----------------

    PlasmaCalendar.EventPluginsManager {
        id: eventPlugins
        enabledPlugins: ["holidaysevents", "alternatecalendar"]
    }

    PlasmaCalendar.Calendar {
        id: cal
        days: 7   // 一周 7 天
        weeks: 6  // 固定 6 行，翻月时高度不跳动
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: root.today

        Component.onCompleted: {
            // 和 Plasma 官方 MonthView 相同的接线方式
            daysModel.setPluginsManager(eventPlugins)
            updateData()
            root.refreshSelectedEvents()
        }

        // 翻月后把选中日期落到新月份的 1 号
        onDisplayedDateChanged: {
            const d = displayedDate
            if (d.getFullYear && !isNaN(d.getTime())) {
                root.selectedDate = new Date(d.getFullYear(), d.getMonth(), 1)
            }
        }
    }

    // 工作日/节假日数据是异步到达的：到齐后刷新底部信息
    Connections {
        target: cal.daysModel
        function onDataChanged() { root.refreshSelectedEvents() }
        function onModelReset() { root.refreshSelectedEvents() }
    }

    // 插件被（重新）加载后重新查询一次，保证节假日/农历不丢
    Connections {
        target: eventPlugins
        function onPluginsChanged() {
            cal.updateData()
            root.refreshSelectedEvents()
        }
    }

    // 跨天刷新“今天”
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            const now = new Date()
            if (now.getDate() !== root.today.getDate()
                    || now.getMonth() !== root.today.getMonth()
                    || now.getFullYear() !== root.today.getFullYear()) {
                root.today = now
            }
        }
    }

    // ---------------- 界面（Kirigami 视觉语言） ----------------

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing * 2
        spacing: Kirigami.Units.largeSpacing

        // 1. 顶部：月份 + 年份 + 翻月/回到今天
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Heading {
                text: cal.monthName
                level: 2
                type: Kirigami.Heading.Type.Primary
                font.family: Sizes.fontFamily
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Kirigami.Heading {
                text: cal.year + "年"
                level: 2
                opacity: 0.7 // 年份稍暗，形成层次感
                font.family: Sizes.fontFamily
            }

            // 不在本月时显示「今」，一键回到今天
            Button {
                visible: !root.showingCurrentMonth
                flat: true
                text: "今"
                font: Kirigami.Theme.smallFont
                onClicked: {
                    cal.resetToToday()
                    root.selectedDate = root.today
                }
                ToolTip.visible: hovered
                ToolTip.text: "回到今天"
            }

            // 上一月 / 下一月
            Repeater {
                model: [
                    { icon: "go-previous-symbolic", tip: "上一月", isNext: false },
                    { icon: "go-next-symbolic", tip: "下一月", isNext: true }
                ]
                Button {
                    required property var modelData
                    flat: true
                    display: AbstractButton.IconOnly
                    icon.name: modelData.icon
                    icon.width: Kirigami.Units.iconSizes.small
                    icon.height: Kirigami.Units.iconSizes.small
                    implicitWidth: Kirigami.Units.gridUnit * 1.5
                    implicitHeight: Kirigami.Units.gridUnit * 1.5
                    onClicked: modelData.isNext ? cal.nextMonth() : cal.previousMonth()
                    ToolTip.visible: hovered
                    ToolTip.text: modelData.tip
                }
            }
        }

        // 2. 星期表头（跟着系统「一周的第一天」旋转）
        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: 7
                Item {
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 1.2

                    // Qt 的星期编号：1=周一 … 7=周日
                    readonly property int weekdayNumber: ((cal.firstDayOfWeek - 1 + index) % 7) + 1
                    readonly property bool isWeekend: weekdayNumber === 6 || weekdayNumber === 7

                    Label {
                        anchors.centerIn: parent
                        text: Qt.locale().dayName(parent.weekdayNumber, Locale.NarrowFormat)
                        color: Kirigami.Theme.textColor
                        opacity: parent.isWeekend ? 0.45 : 0.7
                        font.family: Kirigami.Theme.smallFont.family
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        font.weight: Font.Bold
                    }
                }
            }
        }

        // 3. 日期网格（6 × 7，数据来自 PlasmaCalendar 的 daysModel）
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            columnSpacing: 0
            rowSpacing: Kirigami.Units.smallSpacing / 2

            Repeater {
                model: cal.daysModel

                Item {
                    id: cell

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2.5

                    readonly property int dNum: model.dayNumber
                    readonly property int mNum: model.monthNumber
                    readonly property int yNum: model.yearNumber
                    readonly property bool inMonth: model.isCurrent
                    readonly property int weekday: new Date(yNum, mNum - 1, dNum).getDay()
                    readonly property bool isWeekend: weekday === 0 || weekday === 6
                    // 重大节日（KHolidays 里 isMinor=false 的项，如国庆节/春节）
                    readonly property bool isHoliday: model.containsMajorEventItems === true
                    // 农历日名（alternatecalendar 插件，中文历法下是“初五/廿三”）
                    readonly property string lunarText: model.subDayLabel || ""

                    readonly property bool isToday: yNum === root.today.getFullYear()
                                                    && mNum === root.today.getMonth() + 1
                                                    && dNum === root.today.getDate()
                    readonly property bool isSelected: yNum === root.selectedDate.getFullYear()
                                                       && mNum === root.selectedDate.getMonth() + 1
                                                       && dNum === root.selectedDate.getDate()

                    // 今天 / 选中 的圆底
                    Rectangle {
                        width: Kirigami.Units.gridUnit * 1.5
                        height: Kirigami.Units.gridUnit * 1.5
                        radius: width / 2
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: cell.lunarText !== "" && cell.inMonth ? -Kirigami.Units.smallSpacing : 0
                        visible: cell.isToday || cell.isSelected
                        color: cell.isToday ? Kirigami.Theme.highlightColor
                               : Qt.alpha(Kirigami.Theme.highlightColor, 0.25)
                    }

                    // 日期数字
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: cell.lunarText !== "" && cell.inMonth ? -Kirigami.Units.smallSpacing * 2 : 0
                        text: cell.dNum
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pixelSize: Kirigami.Theme.defaultFont.pixelSize
                        font.weight: Font.DemiBold
                        color: {
                            if (cell.isToday) return Kirigami.Theme.highlightedTextColor
                            if (!cell.inMonth) return Qt.alpha(Kirigami.Theme.textColor, 0.3)
                            if (cell.isHoliday) return Kirigami.Theme.negativeTextColor
                            if (cell.isSelected) return Kirigami.Theme.highlightColor
                            if (cell.isWeekend) return Kirigami.Theme.disabledTextColor
                            return Kirigami.Theme.textColor
                        }
                    }

                    // 农历
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: Kirigami.Units.gridUnit * 0.5
                        visible: cell.inMonth && cell.lunarText !== "" && cell.height >= Kirigami.Units.gridUnit * 1.5
                        text: cell.lunarText
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, cell.width - 2)
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Kirigami.Theme.smallFont.family
                        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        color: cell.isToday ? Kirigami.Theme.highlightedTextColor
                               : cell.isHoliday ? Kirigami.Theme.negativeTextColor
                               : Kirigami.Theme.textColor
                        opacity: 0.7
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectedDate = new Date(cell.yNum, cell.mNum - 1, cell.dNum)
                    }
                }
            }
        }

        // 4. 底部：选中日期的节假日 / 事件（没有就自动收起，不占高度）
        Label {
            Layout.fillWidth: true
            visible: text !== ""
            text: {
                if (!root.selectedEvents || root.selectedEvents.length === 0)
                    return ""
                return root.selectedEvents.map(e => e.title).join(" · ")
            }
            elide: Text.ElideRight
            color: Kirigami.Theme.negativeTextColor
            font.family: Kirigami.Theme.smallFont.family
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            opacity: 0.8
        }
    }
}
