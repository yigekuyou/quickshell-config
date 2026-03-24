import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import Quickshell
import qs.Services

// 保持使用 PopupWindow 作为顶层容器
PopupWindow {
	id: popup
	implicitWidth: 350
	property real targetYOffset: 0
	implicitHeight: contentLayout.implicitHeight + (Kirigami.Units.gridUnit * 2)
	// --- 接口属性 ---
	property int index
	property var notificationData:NotificationManager.sortedTemopraryNotifications[index]// 对应 Quickshell 的 Notification 对象
	visible: true
	color: "transparent"
	mask: null
	// --- 信号 ---
	signal exitFinished()

	// --- 窗口定位逻辑 (根据你的要求) ---
	anchor.window: barWindow
	anchor.edges: Edges.Top | Edges.Right
	anchor.gravity: Edges.Bottom

	property var pos : mapToItem(parentWindow.contentItem, 0, parentWindow.height+30);
	anchor.rect.x: Math.round(pos.x)
	anchor.rect.y: Math.round(pos.y+ targetYOffset)
	onHeightChanged: {
		if (manager) manager._updatePositions();
	}
	// 进场和出场动画
	Control {
		id: content
		anchors.fill: parent
		opacity: 0
		scale: 0.9
		spacing: Kirigami.Units.largeSpacing
		// Kirigami 卡片作为主体
		Kirigami.Card {
			id:notif
			anchors.fill: parent
			anchors.margins: Kirigami.Units.smallSpacing

			// 设置卡片高亮样式（如果是紧急通知）
			background: Rectangle {
				color:  Qt.alpha(Kirigami.Theme.backgroundColor, 0.5)
				radius: Kirigami.Units.gridUnit / 3
				border.color: notificationData.urgency === 2 ? Kirigami.Theme.negativeTextColor : "transparent"
				border.width: 2
				layer.enabled: true
			}

			ColumnLayout {
				anchors.fill: parent
				id: contentLayout
				spacing: Kirigami.Units.smallSpacing

				// 第一行：应用图标 + 应用名 + 时间 + 关闭按钮
				RowLayout {

					Layout.fillWidth: true
					spacing: Kirigami.Units.mediumSpacing
					Kirigami.Icon {
						source: notificationData.appIcon || "notifications"
						Layout.preferredWidth: Kirigami.Units.iconSizes.small
						Layout.preferredHeight: Kirigami.Units.iconSizes.small
					}

					Label {
						text: notificationData.appName
						font: Kirigami.Theme.smallFont
						color: Kirigami.Theme.highlightColor
						elide: Label.ElideRight
						Layout.fillWidth: true
					}

					Label {
						text: notificationData.time
						font: Kirigami.Theme.smallFont
						color: Kirigami.Theme.disabledTextColor
					}

					Button {
						flat: true
						implicitWidth: Kirigami.Units.gridUnit
						implicitHeight: Kirigami.Units.gridUnit
						onClicked: NotificationManager.dismiss(notificationData,false)

						contentItem: Kirigami.Icon {
							source: "window-close"
							color: parent.hovered ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor
						}
					}
				}
				RowLayout {
					Kirigami.Icon {
						source: notificationData.image || notificationData.appIcon || notificationData.appName.toLowerCase()
						Layout.preferredWidth: Kirigami.Units.iconSizes.medium
						Layout.preferredHeight: Kirigami.Units.iconSizes.medium
					}

					ColumnLayout{

						// 第二行：标题 (Summary)
						Label {
							text: notificationData.summary
							font.weight: Font.Bold
							font.pointSize: Kirigami.Theme.defaultFont.pointSize
							Layout.fillWidth: true
							elide: Label.ElideRight
						}
						// 第三行：正文 (Body)
						Label {
							text: notificationData.body
							wrapMode: Label.Wrap
							maximumLineCount: 2
							elide: Label.ElideRight
							Layout.fillWidth: true
							opacity: 0.8
							font.pointSize: Kirigami.Theme.defaultFont.pointSize - 1
						}

					}


				// 第四行：动态按钮 (Actions)
				RowLayout {
					visible: notificationData.actions.length > 0
					Layout.fillWidth: true
					Layout.topMargin: Kirigami.Units.smallSpacing

					Repeater {
						model: notificationData.actions
						Button {
							text: modelData.label
							flat: false
							Layout.fillWidth: true
							onClicked: {
								notificationData.invokeAction(modelData.id);
							}
						}
					}
				}
			}
			}
			// 底部操作按钮（如果有）
			actions: [
				Kirigami.Action {
					visible: notificationData.actions.length > 0
					text: "查看详情"
					icon.name: "entry-edit"
					onTriggered: {
						notificationData.invokeAction(notificationData.actions[0].id);
					}
				}
			]
		}

		// --- 状态动画 ---
		Component.onCompleted: entranceAnim.start()

		ParallelAnimation {
			id: entranceAnim
			NumberAnimation { target: content; property: "opacity"; to: 1; duration: 200 }
			NumberAnimation { target: content; property: "scale"; to: 1; duration: 300; easing.type: Easing.OutBack }
		}

		ParallelAnimation {
			id: exitAnim
			NumberAnimation { target: content; property: "opacity"; to: 0; duration: 200 }
			NumberAnimation { target: content; property: "scale"; to: 0.8; duration: 200 }
			onFinished: popup.exitFinished()
		}
	}

	function startExit() {
		exitAnim.start();
	}
}
