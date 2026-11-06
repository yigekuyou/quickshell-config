import QtQuick
import QtQuick.Layouts
import qs.Config
import org.kde.plasma.workspace.calendar as PlasmaCalendar

// 日历 —— 数据后端换成 KDE Plasma 的日历组件
// ------------------------------------------------------------------
// 网格/月份/年份/星期起始日、法定节假日、农历，全部来自
// `org.kde.plasma.workspace.calendar`（与 Plasma 数字时钟托盘里的日历同源）：
//   * PlasmaCalendar.Calendar        —— 42 格月历数据模型 + 月份导航
//   * PlasmaCalendar.EventPluginsManager
//       - "holidaysevents"     KHolidays 法定节假日（区域取自
//                              ~/.config/plasma_calendar_holiday_regions）
//       - "alternatecalendar"  农历日名（Chinese 历法，
//                              ~/.config/plasma_calendar_alternatecalendar）
// 渲染仍然用本项目自己的 Colorscheme / Sizes 设计令牌，保持动态岛观感统一。
Rectangle {
    id: root

    color: Colorscheme.surface_container_high
    radius: 16 // 与其他组件对齐

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

    // ---------------- 界面 ----------------

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        // 1. 顶部：月份 + 年份 + 翻月/回到今天
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            spacing: 6

            Text {
                text: cal.monthName
                color: Colorscheme.on_surface
                font.family: Sizes.fontFamily
                font.pixelSize: 18
                font.bold: true
            }
            Text {
                text: cal.year + "年"
                color: Colorscheme.on_surface_variant // 年份稍暗，形成层次感
                font.family: Sizes.fontFamily
                font.pixelSize: 18
                font.bold: true
            }

            Item { Layout.fillWidth: true } // 占位，把文字推到左边

            // 不在本月时显示「今」，一键回到今天
            Item {
                visible: !root.showingCurrentMonth
                Layout.preferredWidth: 24
                Layout.preferredHeight: 22

                Rectangle {
                    anchors.fill: parent
                    radius: 11
                    color: todayHover.containsMouse ? Colorscheme.surface_container_highest : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "今"
                        color: Colorscheme.on_surface_variant
                        font.family: Sizes.fontFamily
                        font.pixelSize: 11
                    }
                    HoverHandler { id: todayHover }
                    TapHandler {
                        onTapped: {
                            cal.resetToToday()
                            root.selectedDate = root.today
                        }
                    }
                }
            }

            // 上一月 / 下一月
            Repeater {
                model: [
                    { glyph: "‹", action: "prev" },
                    { glyph: "›", action: "next" }
                ]
                Item {
                    required property var modelData
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 22

                    Rectangle {
                        anchors.fill: parent
                        radius: 11
                        color: navHover.hovered ? Colorscheme.surface_container_highest : "transparent"
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.glyph
                        color: navHover.hovered ? Colorscheme.on_surface : Colorscheme.on_surface_variant
                        font.family: Sizes.fontFamily
                        font.pixelSize: 18
                    }
                    HoverHandler { id: navHover }
                    TapHandler {
                        onTapped: parent.modelData.action === "prev" ? cal.previousMonth() : cal.nextMonth()
                    }
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
                    Layout.preferredHeight: 20

                    // Qt 的星期编号：1=周一 … 7=周日
                    readonly property int weekdayNumber: ((cal.firstDayOfWeek - 1 + index) % 7) + 1
                    readonly property bool isWeekend: weekdayNumber === 6 || weekdayNumber === 7

                    Text {
                        anchors.centerIn: parent
                        text: Qt.locale().dayName(parent.weekdayNumber, Locale.NarrowFormat)
                        color: parent.isWeekend ? Colorscheme.outline : Colorscheme.on_surface_variant
                        font.family: Sizes.fontFamily
                        font.pixelSize: 12
                        font.bold: true
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
            rowSpacing: 2

            Repeater {
                model: cal.daysModel

                Item {
                    id: cell

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: 32

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
                        width: 26
                        height: 26
                        radius: 13
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: cell.lunarText !== "" && cell.inMonth ? -3 : 0
                        color: cell.isToday ? Colorscheme.primary
                               : cell.isSelected ? Colorscheme.surface_container_highest
                               : "transparent"
                    }

                    // 日期数字
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: cell.lunarText !== "" && cell.inMonth ? -8 : 0
                        text: cell.dNum
                        font.family: Sizes.fontFamily
                        font.pixelSize: 13
                        font.bold: cell.isToday || cell.isHoliday
                        color: {
                            if (cell.isToday) return Colorscheme.on_primary
                            if (!cell.inMonth) return Colorscheme.outline_variant
                            if (cell.isHoliday) return Colorscheme.error
                            if (cell.isSelected) return Colorscheme.on_surface
                            if (cell.isWeekend) return Colorscheme.on_surface_variant
                            return Colorscheme.on_surface
                        }
                    }

                    // 农历
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 8
                        visible: cell.inMonth && cell.lunarText !== "" && cell.height >= 30
                        text: cell.lunarText
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, cell.width - 2)
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Sizes.fontFamily
                        font.pixelSize: 9
                        color: cell.isToday ? Colorscheme.on_primary
                               : cell.isHoliday ? Colorscheme.error
                               : Colorscheme.outline
                        opacity: 0.9
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
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            visible: text !== ""
            text: {
                if (!root.selectedEvents || root.selectedEvents.length === 0)
                    return ""
                return root.selectedEvents.map(e => e.title).join(" · ")
            }
            elide: Text.ElideRight
            color: Colorscheme.error
            font.family: Sizes.fontFamily
            font.pixelSize: 11
        }
    }
}
