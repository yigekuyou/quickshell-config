pragma Singleton
import Quickshell
import QtQuick
import qs.Services
import org.kde.kirigami as Kirigami

// Material 3 角色名 → 全部由 Kirigami 主题语义色派生。
//
// 以前这里写死了一整套深色十六进制值，改成派生后：
//   * 跟随 KDE 配色方案（换主题 / 换明暗）；
//   * 跟随高亮色（primary 系列）；
//   * light / dark 两套主题共用同一份定义 —— layer() 混向 textColor，
//     深色主题里是提亮、浅色主题里是压暗，正好等于 M3 的 surface 层级方向。
//
// 对外的属性名保持 M3 角色名不变，旧代码无需改动。
Singleton {
    id: root

    // ==================== 基色 ====================
    readonly property color surface: Kirigami.Theme.backgroundColor
    readonly property color on_surface: Kirigami.Theme.textColor
    readonly property color primary: Kirigami.Theme.highlightColor
    readonly property bool dark: root.surface.hslLightness < 0.5

    // ==================== 壁纸色（优先于主题派生色） ====================
    // 壁纸自己的底色来自 settings.json → wallpaper.backgroundColor。
    //
    // 以前这里没给壁纸留任何出口，后果是：壁纸渲染窗口（PanelWindow / Web.qml）
    // 各自硬编码 #000000，锁屏和所有半透明面板又统一取 Kirigami 主题色，
    // 于是用户在设置里改的壁纸颜色既到不了壁纸层、也到不了任何 surface ——
    // 看起来就是“壁纸的颜色被 Colorscheme 覆盖了”。
    //
    // 现在的约定：壁纸色是一等来源，非空就优先；空串才回落到主题派生色。
    // 需要壁纸衬底的组件（Wallpaper.qml / Web.qml / 锁屏）一律读下面两个属性，
    // 不再自己写死颜色，也不直接读 Settings —— 保证只有一个真相来源。
    readonly property string wallpaper_color: Settings.wallpaper && Settings.wallpaper.backgroundColor !== undefined
        ? String(Settings.wallpaper.backgroundColor) : ""
    // 壁纸衬底（后端出画前的底色 / 锁屏遮罩的底）
    readonly property color wallpaper_background: root.wallpaper_color !== "" ? root.wallpaper_color : root.surface
    // 压在壁纸底色上的文字 / 图标色：按底色明度翻转，浅底黑字、深底白字
    readonly property color on_wallpaper_background: root.wallpaper_background.hslLightness > 0.5 ? "#000000" : "#ffffff"

    // ==================== 混色工具 ====================
    // t = 0 取 c1，t = 1 取 c2
    function mix(c1, c2, t) {
        return Qt.rgba(c1.r + (c2.r - c1.r) * t, c1.g + (c2.g - c1.g) * t, c1.b + (c2.b - c1.b) * t, c1.a + (c2.a - c1.a) * t)
    }

    // M3 的层级方向：越“高”的容器离基色越远（深色主题提亮，浅色主题压暗）
    function layer(amount) {
        return root.mix(root.surface, root.on_surface, amount)
    }

    // 反方向：比基色更“沉”的一层
    function under(amount) {
        return root.mix(root.surface, root.dark ? "#000000" : "#ffffff", amount)
    }

    // 固定色调（fixed 系列）：始终朝白 / 朝黑，不随明暗翻转
    function lighten(c, amount) {
        return root.mix(c, "#ffffff", amount)
    }

    function darken(c, amount) {
        return root.mix(c, "#000000", amount)
    }

    // ==================== surface 层级 ====================
    readonly property color background: root.surface
    readonly property color surface_dim: root.under(0.03)
    readonly property color surface_bright: root.layer(0.12)
    readonly property color surface_container_lowest: root.under(0.05)
    readonly property color surface_container_low: root.layer(0.02)
    readonly property color surface_container: root.layer(0.05)
    readonly property color surface_container_high: root.layer(0.08)
    readonly property color surface_container_highest: root.layer(0.11)
    readonly property color surface_variant: Kirigami.Theme.alternateBackgroundColor
    readonly property color surface_tint: root.primary
    readonly property color source_color: root.primary

    // ==================== on-surface / 描边 ====================
    readonly property color on_background: root.on_surface
    readonly property color on_surface_variant: root.mix(root.on_surface, root.surface, 0.32)
    readonly property color outline: root.mix(root.on_surface, root.surface, 0.5)
    readonly property color outline_variant: root.mix(root.on_surface, root.surface, 0.78)

    // ==================== primary ====================
    readonly property color on_primary: Kirigami.Theme.highlightedTextColor
    readonly property color primary_container: root.mix(root.primary, root.surface, 0.72)
    readonly property color on_primary_container: root.mix(root.primary, root.on_surface, 0.35)
    readonly property color primary_fixed: root.lighten(root.primary, 0.6)
    readonly property color primary_fixed_dim: root.lighten(root.primary, 0.35)
    readonly property color on_primary_fixed: root.darken(root.primary, 0.75)
    readonly property color on_primary_fixed_variant: root.darken(root.primary, 0.55)
    readonly property color inverse_primary: root.mix(root.primary, root.surface, 0.35)

    // ==================== secondary ====================
    readonly property color secondary: root.mix(root.on_surface, root.surface, 0.42)
    readonly property color on_secondary: root.surface
    readonly property color secondary_container: root.layer(0.1)
    readonly property color on_secondary_container: root.mix(root.on_surface, root.surface, 0.1)
    readonly property color secondary_fixed: root.mix(root.on_surface, root.surface, 0.35)
    readonly property color secondary_fixed_dim: root.mix(root.on_surface, root.surface, 0.55)
    readonly property color on_secondary_fixed: root.surface
    readonly property color on_secondary_fixed_variant: root.mix(root.on_surface, root.surface, 0.55)

    // ==================== tertiary ====================
    readonly property color tertiary: root.mix(root.primary, root.on_surface, 0.45)
    readonly property color on_tertiary: root.surface
    readonly property color tertiary_container: root.mix(root.tertiary, root.surface, 0.7)
    readonly property color on_tertiary_container: root.mix(root.tertiary, root.on_surface, 0.3)
    readonly property color tertiary_fixed: root.lighten(root.tertiary, 0.6)
    readonly property color tertiary_fixed_dim: root.lighten(root.tertiary, 0.35)
    readonly property color on_tertiary_fixed: root.surface
    readonly property color on_tertiary_fixed_variant: root.mix(root.tertiary, root.surface, 0.45)

    // ==================== error ====================
    readonly property color error: Kirigami.Theme.negativeTextColor
    readonly property color on_error: root.surface
    readonly property color error_container: root.mix(root.error, root.surface, 0.72)
    readonly property color on_error_container: root.mix(root.error, root.on_surface, 0.25)

    // ==================== inverse / scrim ====================
    readonly property color inverse_surface: root.on_surface
    readonly property color inverse_on_surface: root.surface
    readonly property color scrim: "#000000"
    readonly property color shadow: "#000000"
}
