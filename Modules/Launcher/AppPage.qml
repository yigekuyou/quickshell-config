import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
PopupWindow {
	id:root
	anchor.window: panelWindow
	anchor.edges: Edges.Bottom
	anchor.gravity: Edges.Top
	property var pos : mapToItem(parentWindow.contentItem, parentWindow.width/2,0);
	anchor.rect.x: Math.round(pos.x)
	anchor.rect.y: Math.round(pos.y)
	grabFocus: true

	visible: true
	mask: null
	implicitWidth: Kirigami.Units.gridUnit * 40
	implicitHeight: Math.max(Sizes.barHeight, Kirigami.Units.gridUnit * 30 )
	color: "transparent"
Kirigami.ShadowedRectangle {
		anchors.fill: parent
		radius: Kirigami.Units.smallSpacing
		color:Qt.alpha(Kirigami.Theme.backgroundColor,0.5)
		// 边框使用 Kirigami 标准色
		shadow.color: Qt.alpha(0, 0, 0, 0.3)
		shadow.size: 10
		shadow.yOffset: 2

		border.color: Kirigami.Theme.focusColor
		border.width: 1

		RowLayout {
			anchors.fill: parent
			anchors.margins: Kirigami.Units.largeSpacing
			spacing: Kirigami.Units.smallSpacing

			Rectangle {
				Layout.preferredWidth: Kirigami.Units.gridUnit * 8
				Layout.fillHeight: true
				color: Qt.darker(Kirigami.Theme.backgroundColor, 1.05) // 稍微深一点的背景区分
				radius: Kirigami.Units.smallSpacing

				ListView {
					id: categoryList
					anchors.fill: parent
					anchors.margins: Kirigami.Units.smallSpacing
					model: LauncherService.categories
					spacing: 2
					clip: true

					delegate: ItemDelegate {
						width: parent.width
						text: modelData.name
						highlighted: LauncherService.categories === modelData

						onClicked: {
							appGrid.model = modelData.apps;
						}
					}
				}
			}
			ColumnLayout{
				Kirigami.SearchField {
					id: searchInput
					Layout.fillWidth: true
					placeholderText: qsTr("搜索应用...")

					text: LauncherService.searchText=""
					onTextChanged:{
						appGrid.currentIndex = 0
						appGrid.model=LauncherService.model
						LauncherService.searchText = text
					}

					// 自动聚焦
					Component.onCompleted: forceActiveFocus()
					onVisibleChanged: if (visible) forceActiveFocus()

					// 按键控制逻辑
					Keys.onPressed: (event) => {
						switch (event.key) {
							case Qt.Key_Down:
								resultsList.incrementCurrentIndex();
								break;
							case Qt.Key_Up:
								resultsList.decrementCurrentIndex();
								break;
							case Qt.Key_Return:
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
			ScrollView {
				Layout.fillWidth: true
				Layout.fillHeight: true
				clip: true
				ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

				GridView {
					id: appGrid
					// 注意：这里的 model 应该跟随当前选中的分类
					model: []

					cellWidth: width / 4 // 动态计算列数，例如一行4个
					cellHeight: Kirigami.Units.gridUnit * 6

					delegate: Kirigami.AbstractCard {
						// 减去间距防止溢出
						implicitWidth: appGrid.cellWidth - Kirigami.Units.largeSpacing
						implicitHeight: appGrid.cellHeight - Kirigami.Units.largeSpacing
						showClickFeedback: true

						// 直接在 Card 上处理点击，不需要额外的 MouseArea 覆盖
						onClicked: {
							LauncherService.launch(index);
							popudroot.visible = false;
						}

						ColumnLayout {
							anchors.centerIn: parent
							spacing: Kirigami.Units.smallSpacing

							Kirigami.Icon {
								Layout.alignment: Qt.AlignHCenter
								source: modelData.icon || "system-run"
								implicitWidth: Kirigami.Units.gridUnit * 2
								implicitHeight: Kirigami.Units.gridUnit * 2
							}

							Text {
								text: modelData.name
								wrapMode:Text.WrapAnywhere
								Layout.fillWidth: true
								horizontalAlignment: Text.AlignHCenter
								elide: Text.ElideRight
								color: Kirigami.Theme.textColor
								font.pointSize: Kirigami.Units.gridUnit * 0.5
							}
						}
					}

				}
			}
			}
		}
	}

}
