import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// 仪表盘内容 —— 左侧（日历 + 系统信息）/ 右侧（课表）。
// 视觉语言与 ClockContent / MediaContent 统一：
// 透明分区 + Kirigami.Separator 分隔 + Kirigami.Units 边距，
// 三个区域直接浮在 DynamicIsland 的半透明背景上（同 MediaContent 的 Kirigami.Card）。
Item {
    id: root

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.gridUnit
        spacing: Kirigami.Units.largeSpacing

        // 1. 左侧区域 (权重 60%)
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 60
            spacing: Kirigami.Units.largeSpacing

            // 1.1 日历 + 系统/头像（填满左侧高度）
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.largeSpacing

                CalendarWidget {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 60
                }

                // 垂直分隔线 (Kirigami 风格)
                Kirigami.Separator {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    opacity: 0.5
                }

                SysInfoWidget {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 40
                }
            }
        }

        // 垂直分隔线 (Kirigami 风格)
        Kirigami.Separator {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            opacity: 0.5
        }

        // 2. 右侧区域：经典的细长长方形课表 (权重 40%)
        ScheduleWidget {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 40
        }
    }
}
