import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.config

PopupWindow {
	id: root

	property var rootMenuHandle: null
	property string trayName: ""

	implicitWidth: 240
	implicitHeight: Math.min(600, mainLayout.implicitHeight + 20)
	color: "transparent"

	// 每次打开重置到根菜单
	onVisibleChanged: if (visible) menuStack.clear()

	ListModel { id: menuStack }

	property var currentSubMenuHandle: {
		return menuStack.count === 0 ? null : menuStack.get(menuStack.count - 1).handle
	}

	// 根菜单数据源
	QsMenuOpener {
		id: rootOpener
		menu: root.rootMenuHandle
	}

	// 子菜单数据源
	QsMenuOpener {
		id: subOpener
		menu: root.currentSubMenuHandle
	}

	QsMenuAnchor {
		id: hydrator
		anchor.window: root
		anchor.item: mainLayout
		anchor.rect.x: root.width / 2
		anchor.rect.y: root.height / 2
		anchor.rect.width: 1
		anchor.rect.height: 1
	}

	function navigateToSubmenu(handle, text) {
		if (!handle) return
			menuStack.append({ "handle": handle, "title": text })

			// 触发 DBus 预取信号 [cite: 40, 41]
			hydrator.menu = handle
			hydrator.open()
			hydrator.close()
	}

	// 核心 UI 结构
	Rectangle {
		anchors.fill: parent
		color: Colorscheme.surface_container
		radius: 12
		border.color: Colorscheme.outline_variant
		clip: true

		ColumnLayout {
			id: mainLayout
			width: parent.width
			spacing: 0

			// 菜单列表
			Repeater {
				// 根据是否有子菜单切换数据源
				model: root.currentSubMenuHandle ? subOpener.entries : rootOpener.entries

				delegate: Rectangle {
					property bool isSeparator: modelData.isSeparator
					Layout.fillWidth: true
					height: isSeparator ? 1 : 36
					color: itemMa.containsMouse ? Colorscheme.secondary_container : "transparent"

					RowLayout {
						anchors.fill: parent
						anchors.margins: { left: 12; right: 12 }
						visible: !isSeparator

						Text {
							text: modelData.text
							Layout.fillWidth: true
							color: Colorscheme.on_surface
						}

						// 子菜单箭头
						Text {
							visible: !!modelData.subMenu
							text: "›"
							font.pixelSize: 18
							color: Colorscheme.tertiary
						}
					}

					MouseArea {
						id: itemMa
						anchors.fill: parent
						hoverEnabled: true
						onClicked: {
							if (modelData.subMenu) {
								navigateToSubmenu(modelData.subMenu, modelData.text)
							} else {
								modelData.trigger() // 执行菜单动作
								root.visible = false
							}
						}
					}
				}
			}
		}
	}
}
