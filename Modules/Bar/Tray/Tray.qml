import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.Config
import qs.Modules.Bar.common
import org.kde.kirigami as Kirigami

// 顶栏系统托盘。托盘里每个图标有自己的点击逻辑，所以这个胶囊只当容器：
// interactive: false 关掉 BarButton 自己的光标/点击处理，避免和 TrayItem 抢事件。
BarButton {
    id: root

    interactive: false
    // 内边距不再写死：跟随设置「托盘 → 内边距」（BarButton 默认 Sizes.barPadding）

    content: Component {
        RowLayout {
            // 图标间距跟随设置「托盘 → 按钮间距」
            spacing: Sizes.barSpacing

            Repeater {
                model: SystemTray.items
                delegate: TrayItem {
                    Layout.alignment: Qt.AlignVCenter
                }
            }
        }
    }
}