import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Widget.common
import qs.Services
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

PanelWindow {
	id:popudroot
	anchors { top: true; left: true; right: true }
	exclusionMode:ExclusionMode.Ignore
	property int sideMargin: screen.width / 3
	height: Kirigami.Units.gridUnit * 30
	margins {
		left: sideMargin
		right: sideMargin
		top: Kirigami.Units.smallSpacing+Sizes.barHeight // 顶部留一点点像素缝隙更美观
	}
	WlrLayershell.namespace: "rofi-launcher-overlay"
	focusable:true
	Kirigami.ShadowedRectangle {
		anchors.fill: parent
		radius: Kirigami.Units.smallSpacing
		color: Kirigami.Theme.backgroundColor
		// 边框使用 Kirigami 标准色
		shadow.color: Qt.rgba(0, 0, 0, 0.3)
		shadow.size: 10
		shadow.yOffset: 2

		border.color: Kirigami.Theme.focusColor
		border.width: 1

		ColumnLayout {
			anchors.fill: parent
			anchors.margins: Kirigami.Units.largeSpacing
			spacing: Kirigami.Units.smallSpacing

			// 1. Kirigami 搜索框：自带图标和清理按钮
			Kirigami.SearchField {
				id: searchInput
				Layout.fillWidth: true
				placeholderText: qsTr("搜索应用...")

				text: LauncherService.searchText=""
				onTextChanged: LauncherService.searchText = text

				// 自动聚焦
				Component.onCompleted: forceActiveFocus()
				onVisibleChanged: if (visible) forceActiveFocus()

				// 按键控制逻辑
				Keys.onPressed: (event) => {
					switch (event.key) {
						case Qt.Key_Enter: // 通常建议同时处理小键盘的回车
							LauncherService.launch(resultsList.currentIndex);
							popudroot.destroy();
							break;
						case Qt.Key_Escape:
							popudroot.destroy();
							break;
					}
				}
			}

			// 2. 结果列表
			ListView {
				id: resultsList
				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				model: LauncherService.model
				highlightFollowsCurrentItem: true
				// 列表项委托
				delegate:FormCard.FormButtonDelegate{
					id: delegateItem
					width: resultsList.width
					text: modelData.name
					description:modelData.comment
					icon.name:modelData.icon ?? "system-run"
					palette.text: highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
					palette.buttonText: highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
					// 状态绑定
					highlighted: ListView.isCurrentItem

					// 背景：手动实现 Kirigami 选中效果
					background: Rectangle {
						opacity: delegateItem.highlighted ? 0.3 : (delegateItem.hovered ? 0.15 : 0)
						color: delegateItem.highlighted ? Kirigami.Theme.highlightColor : Kirigami.Theme.hoverColor
						radius: 4

						// 左侧选中指示条（KDE 经典风格）
						Rectangle {
							anchors.left: parent.left
							anchors.verticalCenter: parent.verticalCenter
							width: Kirigami.Units.smallSpacing
							height: parent.height * 0.6
							color: Kirigami.Theme.highlightColor
							visible: delegateItem.highlighted
						}
					}
					onClicked: {
						LauncherService.launch(index);
						popudroot.destroy();
					}
					Keys.onPressed: (event) => {
						switch (event.key) {
							case Qt.Key_Down:
								incrementCurrentIndex();
								break;
							case Qt.Key_Up:
								decrementCurrentIndex();
								break;
							case Qt.Key_Enter:
								LauncherService.launch(currentIndex);
								popudroot.destroy();
								break;
							case Qt.Key_Escape:
								popudroot.destroy();
								break;
						}
					}
				}
			}
		}
	}
}
