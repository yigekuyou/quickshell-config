import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// ============================================================================
// 设置行：颜色。整个设置面板里“选颜色”只走这一个控件。
//
// 和 SettingsSwitchRow / SettingsSliderRow / SettingsComboRow 同一层：
// FormCard.AbstractFormDelegate，所以行高、左右留白、悬停高亮、焦点、
// 无障碍标签都由 Kirigami 统一，页与页之间不会再出现“壁纸页的行比状态栏页
// 窄一圈 / 字号不一样”这种拼贴感。
//
// 值一律当字符串处理，因为壁纸选项的来源有三种写法：
//   "#1e90ff"         十六进制
//   "1 1 1"            Wallpaper Engine 的浮点 RGB（0–1）
//   "255 0 0"          Wallpaper Engine 的整数 RGB（0–255）
// 色块按上面三种解析；文本框里始终是原样字符串，不替用户改写格式。
//
// 用法：
//   SettingsColorRow {
//       text: qsTr("壁纸底色")
//       description: qsTr("…")
//       raw: Settings.wallpaper.backgroundColor
//       onEdited: v => Settings.wallpaper.backgroundColor = v
//   }
// ============================================================================
FormCard.AbstractFormDelegate {
    id: root

    // text 用继承的（ItemDelegate 自带）
    property string description: ""
    property string iconName: ""
    // 原始字符串值（保存成什么就是什么）
    property string raw: ""
    // false = 该选项属于 WE 插件但当前渲染器不消费，整行置灰
    property bool wired: true

    signal edited(string value)

    // 把三种写法都变成能显示的颜色；解析不了就当透明，别让预览块直接黑掉
    readonly property color swatchColor: root.parseColor(root.raw)

    function parseColor(text: string): color {
        const s = String(text || "").trim();
        if (s === "")
            return "transparent";

        // "1 1 1" / "0.5 0.2 0.1" / "255 0 0"：空格或逗号分隔的三个数字
        const parts = s.split(/[\s,]+/);
        if (parts.length === 3) {
            const nums = parts.map(p => Number(p));
            if (nums.every(n => !isNaN(n))) {
                // 三个分量都 ≤ 1 时按 0–1 处理，否则按 0–255
                const scale = Math.max(nums[0], nums[1], nums[2]) <= 1.0001 ? 1 : 255;
                return Qt.rgba(nums[0] / scale, nums[1] / scale, nums[2] / scale, 1);
            }
        }

        // "#rrggbb" / "#aarrggbb" / "transparent" / 颜色名：交给 Qt 自己认
        return s;
    }

    Layout.fillWidth: true
    enabled: root.wired

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                visible: root.iconName !== ""
                source: root.iconName
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: implicitWidth
                color: root.wired ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                Layout.alignment: Qt.AlignVCenter
            }

            Label {
                Layout.fillWidth: true
                text: root.text
                elide: Text.ElideRight
                maximumLineCount: 1
                color: root.wired ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
            }

            // 预览色块：跟 Kirigami 圆形色卡一样的小方块 + 细描边。
            // 只在色块自己身上画，不叠任何子项 —— 半透明色需要露出底下的
            // 卡片背景才看得出透明度，多铺一层“棋盘”反而是盖住它。
            Rectangle {


                Layout.preferredWidth: Kirigami.Units.gridUnit * 1.4
                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.4
                Layout.alignment: Qt.AlignVCenter
                radius: Kirigami.Units.smallSpacing
                color: root.swatchColor
                border.width: 1
                border.color: Qt.alpha(Kirigami.Theme.textColor, 0.35)
            }

            TextField {
                id: field

                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 6
                Layout.maximumWidth: Kirigami.Units.gridUnit * 14
                enabled: root.wired
                text: root.raw
                placeholderText: qsTr("#rrggbb 或 255 255 255")
                selectByMouse: true
                // 只有真的变了才写回，避免控件销毁时给模型凭空落一份默认值
                onEditingFinished: {
                    if (field.text !== root.raw)
                        root.edited(field.text);
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: root.description !== ""
            text: root.description
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
    }

    // 模型侧改了值（换壁纸 / 重新载入配置）时同步回文本框，
    // 但不要打断正在输入的用户
    onRawChanged: {
        if (!field.activeFocus && field.text !== root.raw)
            field.text = root.raw;
    }
}