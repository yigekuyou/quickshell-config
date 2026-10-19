pragma Singleton
import Quickshell
import org.kde.kirigami as Kirigami

// 全项目尺寸 / 字体的唯一来源。
// 所有数值都由 Kirigami.Units / Kirigami.Theme 的字体度量派生，
// 换字体、改缩放（KDE 系统设置里的字号）时跟着一起变，
// 各模块里不再散落魔法数字。
Singleton {
    id: root

    // ==================== 基础度量 ====================
    readonly property real gridUnit: Kirigami.Units.gridUnit
    readonly property real smallSpacing: Kirigami.Units.smallSpacing
    readonly property real largeSpacing: Kirigami.Units.largeSpacing
    readonly property real cornerRadius: Kirigami.Units.gridUnit * 0.5
    readonly property real barHeight: Kirigami.Units.gridUnit * 1.6

    // ==================== 字体 ====================
    readonly property string fontFamily: Kirigami.Theme.defaultFont.family
    readonly property string fontFamilyMono: "Monospace"
    // pointSize 可能是 -1（像素字号），给出兜底值，避免把 -1 赋给 font.pointSize
    readonly property real defaultPointSize: Kirigami.Theme.defaultFont.pointSize > 0 ? Kirigami.Theme.defaultFont.pointSize : 10
    readonly property real fontSize: root.defaultPointSize
    readonly property real smallFontSize: Math.max(root.defaultPointSize - 1, 6)

    // ==================== 全局菜单 · 顶栏菜单条 ====================
    readonly property real menuBarFontSize: root.fontSize
    // 单个顶层项左右合计留白（文字两侧各一半）
    readonly property real menuBarItemPadding: Kirigami.Units.gridUnit * 0.55
    readonly property real menuBarItemRadius: Kirigami.Units.gridUnit * 0.35
    // 菜单条宽度上限：菜单再多也不能把顶栏其他部件挤走。
    // 到上限后菜单条整体压缩（文字省略），压到下面这个下限还放不下才横向滚动。
    readonly property real menuBarMaxWidth: Kirigami.Units.gridUnit * 40
    // 单个顶层项的宽度下限：压缩时每项都不会比它更窄（再窄就只剩省略号了）
    readonly property real menuBarItemMinWidth: Kirigami.Units.gridUnit * 1.6
    // 溢出时右边缘渐隐宽度
    readonly property real menuBarFadeWidth: Kirigami.Units.gridUnit * 0.8

    // ==================== 全局菜单 · 弹出菜单 ====================
    // 宽度按最长文本自适应，夹在 min / max 之间
    readonly property real menuPopupWidthMin: Kirigami.Units.gridUnit * 10
    readonly property real menuPopupWidthMax: Kirigami.Units.gridUnit * 16
    // 除文本外的横向开销：左右内边距 + 勾选列 + 图标 + 子菜单箭头
    readonly property real menuRowChrome: Kirigami.Units.gridUnit * 3.2
    readonly property real menuPopupMaxHeight: Kirigami.Units.gridUnit * 22
    readonly property real menuPopupPadding: Kirigami.Units.gridUnit * 0.2
    readonly property real menuItemHeight: Kirigami.Units.gridUnit * 1.6
    readonly property real menuItemSpacing: Kirigami.Units.gridUnit * 0.3
    readonly property real menuItemPaddingLeft: Kirigami.Units.gridUnit * 0.55
    readonly property real menuItemPaddingRight: Kirigami.Units.gridUnit * 0.4
    readonly property real menuItemRadius: Kirigami.Units.gridUnit * 0.25
    readonly property real menuItemHighlightMargin: Kirigami.Units.gridUnit * 0.1
    readonly property real menuSeparatorHeight: Kirigami.Units.gridUnit * 0.55
    readonly property real menuSeparatorMargin: Kirigami.Units.gridUnit * 0.55
    readonly property real menuFontSize: root.fontSize
    readonly property real menuShortcutFontSize: root.smallFontSize
    readonly property real menuIndicatorWidth: Kirigami.Units.gridUnit * 1.0
    readonly property real menuIconSize: Kirigami.Units.iconSizes.small
    readonly property real menuArrowFontSize: root.smallFontSize
    readonly property real menuScrollBarWidth: Math.round(Kirigami.Units.smallSpacing + 5)
    readonly property real menuScrollBarThickness: Math.round(Kirigami.Units.smallSpacing * 0.7)
    readonly property real menuShadowSize: Kirigami.Units.gridUnit * 0.8
    readonly property real menuShadowYOffset: Kirigami.Units.gridUnit * 0.2
    readonly property real menuBorderWidth: 1
}
