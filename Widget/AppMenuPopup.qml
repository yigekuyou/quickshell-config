import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import com.github.yigekuyou.appmenu
import qs.Config
import org.kde.kirigami as Kirigami

// 单层全局菜单弹窗。子菜单通过内部 Loader 再实例化一个本文件（文件级递归），
// 因此任意深度的级联菜单都能展开。
//
// 尺寸全部来自 Config/Sizes.qml（其值又派生自 Kirigami 的 gridUnit / 字体度量），
// 这里不写任何魔法数字。
//
// 锚定：打开时命令式调用 updateAnchor()（PopupAnchor 直接映射到 xdg-positioner，
// edges 是锚点在锚矩形上的位置，gravity 是弹窗相对锚点展开的方向）：
//   顶层（菜单条下拉）：锚点取菜单项底边左角，向右下方展开；
//   子菜单（级联）：    锚点取整行的右上角，向右下方展开。
//   —— 和 Qt 原生 QMenu 在 Wayland 上的定位一致（见 qtwayland platformmenu）。
//   不写声明式 binding：anchor.item 的响应式求值和 PopupAnchor 内部的重定位
//   会互相触发（Quickshell 已知的反馈环），表现为弹窗飞到屏幕最下面。
PopupWindow {
    id: root

    property var menuModel: null // 本弹窗渲染的 DBusMenuModel
    property var parentModel: null // 本弹窗由 parentModel 的 parentRow 展开而来
    property int parentRow: -1 // 在父模型中展开的那一行
    property var parentPopup: null // 上一层弹窗（向上找顶层用）
    property int childRow: -1 // 本模型中已展开子菜单的行（-1 = 无）
    property var childPopup: null // 子弹窗
    property Item anchorItem: null
    property bool submenuMode: false // false = 顶栏下拉, true = 行级联
    property var pendingChild: null // 待应用到 Loader 上的子弹窗参数

    // 宽度按最长文本自适应（见 recomputeWidth），高度封顶后可滚动
    property real popupWidth: Sizes.menuPopupWidthMin

    visible: false
    grabFocus: true
    color: "transparent"
    implicitWidth: bg.implicitWidth
    implicitHeight: bg.implicitHeight

    onVisibleChanged: if (!visible)
        root.cleanup()
    onMenuModelChanged: root.recomputeWidth()

    // ==================== 宽度测量 ====================
    // DBusMenuModel 角色号：TextRole = Qt.UserRole + 3 = 259，ShortcutRole = +12 = 268
    readonly property int _textRole: 259
    readonly property int _shortcutRole: 268

    TextMetrics {
        id: textMetrics

        font.pointSize: Sizes.menuFontSize
    }

    TextMetrics {
        id: shortcutMetrics

        font.pointSize: Sizes.menuShortcutFontSize
    }

    function recomputeWidth() {
        const m = root.menuModel
        if (!m) {
            root.popupWidth = Sizes.menuPopupWidthMin
            return
        }
        let widest = 0
        for (let r = 0; r < m.count; ++r) {
            const idx = m.index(r, 0)
            textMetrics.text = m.data(idx, root._textRole) || ""
            let rowWidth = textMetrics.advanceWidth
            const shortcut = m.data(idx, root._shortcutRole)
            if (shortcut) {
                shortcutMetrics.text = shortcut
                rowWidth += shortcutMetrics.advanceWidth + Sizes.menuItemSpacing * 2
            }
            widest = Math.max(widest, rowWidth)
        }
        root.popupWidth = Math.min(Math.max(widest + Sizes.menuRowChrome, Sizes.menuPopupWidthMin), Sizes.menuPopupWidthMax)
    }

    // 锚定不能写声明式 binding：anchor.item 的响应式求值和 PopupAnchor 内部
    // 的重定位会互相触发（Quickshell 已知的反馈环，SlideWindow 踩过同一个坑），
    // 改成打开时命令式设置一次。
    property bool _updatingAnchor: false

    function updateAnchor() {
        if (root._updatingAnchor)
            return
        root._updatingAnchor = true
        if (root.anchorItem) {
            root.anchor.window = null
            root.anchor.item = root.anchorItem
            if (root.submenuMode) {
                root.anchor.edges = Edges.Right | Edges.Top
                root.anchor.gravity = Edges.Right | Edges.Bottom
            } else {
                root.anchor.edges = Edges.Bottom | Edges.Left
                root.anchor.gravity = Edges.Bottom | Edges.Right
            }
            root.anchor.adjustment = PopupAdjustment.Flip | PopupAdjustment.Slide
        }
        root._updatingAnchor = false
    }

    // 关掉自己以及整条子链，并通知应用“子菜单已收起”。
    // parentModel 通常还有引用，subMenuClosed 发给已经换掉的旧模型也只是空操作。
    function cleanup() {
        if (root.childPopup) {
            root.childPopup.visible = false
            root.childPopup = null
        }
        root.childRow = -1
        if (root.parentModel && root.parentRow >= 0)
            root.parentModel.subMenuClosed(root.parentRow)
        root.parentRow = -1
        root.parentModel = null
        root.anchorItem = null
    }

    // 从本层向上找到顶层弹窗整体收起（点叶子项 / 点外面时用）
    function closeChain() {
        let p = root
        while (p.parentPopup)
            p = p.parentPopup
        p.visible = false
    }

    // 顶层菜单之间切换（或首次打开），由 AppMenuBar 调用。
    // 旧状态先通知到位，再换模型，全程不关窗口，grabFocus 不会失效。
    function switchModel(sub, m, row, item) {
        if (root.childPopup) {
            root.childPopup.visible = false
            root.childPopup = null
        }
        root.childRow = -1
        if (root.parentModel && root.parentRow >= 0 && root.parentRow !== row)
            root.parentModel.subMenuClosed(root.parentRow)
        root.menuModel = sub
        root.parentModel = m
        root.parentRow = row
        root.anchorItem = item
        root.updateAnchor()
        m.subMenuOpened(row)
        root.visible = true
    }

    Kirigami.ShadowedRectangle {
        id: bg

        implicitWidth: root.popupWidth
        implicitHeight: Math.min(list.contentHeight + Sizes.menuPopupPadding * 2, Sizes.menuPopupMaxHeight)
        radius: Sizes.cornerRadius
        color: Kirigami.Theme.backgroundColor
        border.width: Sizes.menuBorderWidth
        border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
        shadow.color: Qt.rgba(0, 0, 0, 0.25)
        shadow.size: Sizes.menuShadowSize
        shadow.yOffset: Sizes.menuShadowYOffset

        ListView {
            id: list

            anchors.fill: parent
            anchors.margins: Sizes.menuPopupPadding
            clip: true
            model: root.menuModel
            // 注意：delegate 里不能写 required property —— 写了之后引擎就不再注入
            // model 角色，统一用 model.xxx 访问
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            spacing: 0

            ScrollBar.vertical: ScrollBar {
                policy: list.contentHeight > list.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                interactive: true
                implicitWidth: Sizes.menuScrollBarWidth
                contentItem: Rectangle {
                    implicitWidth: Sizes.menuScrollBarThickness
                    radius: Sizes.menuScrollBarThickness / 2
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.35)
                }
            }

            delegate: Item {
                id: rowItem

                width: list.width
                height: model.separator === true ? Sizes.menuSeparatorHeight : Sizes.menuItemHeight
                opacity: model.enabled === false ? 0.4 : 1.0

                // 悬停高亮 / 已展开标记
                Rectangle {
                    visible: model.separator !== true
                    anchors.fill: parent
                    anchors.margins: Sizes.menuItemHighlightMargin
                    radius: Sizes.menuItemRadius
                    color: (hover.hovered || root.childRow === index) ? Qt.alpha(Kirigami.Theme.highlightColor, 0.3) : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: Kirigami.Units.shortDuration
                        }
                    }
                }

                // 分隔线
                Rectangle {
                    visible: model.separator === true
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Sizes.menuSeparatorMargin
                    anchors.rightMargin: Sizes.menuSeparatorMargin
                    height: Sizes.menuBorderWidth
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Sizes.menuItemPaddingLeft
                    anchors.rightMargin: Sizes.menuItemPaddingRight
                    spacing: Sizes.menuItemSpacing
                    visible: model.separator !== true

                    // 勾选 / 单选指示
                    Label {
                        visible: model.toggleType !== undefined && model.toggleType !== ""
                        text: model.toggleType === "radio" ? (model.toggleState === 1 ? "◉" : "○") : (model.toggleState === 1 ? "✓" : "")
                        color: Kirigami.Theme.activeTextColor
                        font.pointSize: Sizes.menuFontSize
                        Layout.minimumWidth: Sizes.menuIndicatorWidth
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Kirigami.Icon {
                        visible: model.iconName !== undefined && model.iconName !== ""
                        source: model.iconName
                        implicitWidth: Sizes.menuIconSize
                        implicitHeight: Sizes.menuIconSize
                        color: Kirigami.Theme.textColor
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Label {
                        text: model.text !== undefined ? model.text : ""
                        color: Kirigami.Theme.textColor
                        font.pointSize: Sizes.menuFontSize
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // 快捷键
                    Label {
                        visible: model.shortcut !== undefined && model.shortcut !== ""
                        text: model.shortcut
                        color: Kirigami.Theme.disabledTextColor
                        font.pointSize: Sizes.menuShortcutFontSize
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // 子菜单箭头
                    Label {
                        visible: model.hasSubMenu === true
                        text: "▸"
                        color: Kirigami.Theme.disabledTextColor
                        font.pointSize: Sizes.menuArrowFontSize
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                HoverHandler {
                    id: hover

                    enabled: model.separator !== true && model.enabled !== false
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        // 悬停到带子菜单的行时直接级联展开（标准菜单行为）
                        if (hover.hovered && model.hasSubMenu === true && root.childRow !== index)
                            root.openChild(index, rowItem)
                    }
                }

                TapHandler {
                    enabled: model.separator !== true && model.enabled !== false
                    onTapped: {
                        if (model.hasSubMenu === true) {
                            root.openChild(index, rowItem)
                        } else {
                            root.menuModel.activate(index)
                            root.closeChain()
                        }
                    }
                }
            }
        }
    }

    // ==================== 子菜单（按需实例化，避免无限递归） ====================
    Loader {
        id: childLoader

        active: false
        source: "AppMenuPopup.qml"
        onLoaded: root.applyChild()
    }

    function openChild(row, item) {
        if (!root.menuModel || row < 0)
            return
        if (row === root.childRow && root.childPopup)
            return
        const sub = root.menuModel.subMenu(row)
        if (!sub)
            return
        // 切到另一行之前先把旧子链收掉（子链 cleanup 会发 subMenuClosed）
        if (root.childPopup) {
            root.childPopup.visible = false
            root.childPopup = null
        }
        root.childRow = row
        root.menuModel.subMenuOpened(row)
        root.pendingChild = {
            "model": sub,
            "anchor": item
        }
        if (childLoader.active)
            root.applyChild()
        else
            childLoader.active = true
    }

    function applyChild() {
        if (!root.pendingChild || !childLoader.item)
            return
        const popup = childLoader.item
        popup.submenuMode = true
        popup.menuModel = root.pendingChild.model
        popup.parentModel = root.menuModel
        popup.parentRow = root.childRow
        popup.parentPopup = root
        popup.anchorItem = root.pendingChild.anchor
        popup.updateAnchor()
        root.childPopup = popup
        popup.visible = true
        root.pendingChild = null
    }
}
