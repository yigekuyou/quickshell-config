import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import Quickshell
import qs.Services
import org.kde.kirigamiaddons.formcard as FormCard
import org.kde.kirigami as Kirigami

// 保持使用 PopupWindow 作为顶层容器
PopupWindow {
	id: popup
	implicitWidth: Kirigami.Units.gridUnit*18
	property real targetYOffset: 0
	implicitHeight: notif.implicitHeight + (Kirigami.Units.gridUnit * 2)
	// --- 接口属性 ---
	required property int index
	property var notificationData:NotificationManager.sortedTemopraryNotifications[index]// 对应 Quickshell 的 Notification 对象
	visible: true
	color: "transparent"
	mask: null
	// --- 信号 ---
	signal reload()
	property alias timereload: timereload
	Timer {
		id:timereload
		interval: 5000  ; running:true; repeat: true
		onTriggered:{
			reload()
		}
	}
	// --- 窗口定位逻辑 (根据你的要求) ---
	anchor.window: barWindow
	anchor.edges: Edges.Top | Edges.Right
	anchor.gravity: Edges.Bottom

	anchor.rect.x: Math.round(0)
	anchor.rect.y: Math.round(targetYOffset)
	onHeightChanged: {
		if (manager) manager._updatePositions();
	}
	// 进场和出场动画		// Kirigami 卡片作为主体
	Kirigami.Card{
		id:content
		anchors.fill: parent
		icon.name:notificationData.appIcon || notificationData.appName.toLowerCase()
		header: RowLayout {
			Layout.fillWidth: true
			Layout.margins: Kirigami.Units.smallSpacing
			spacing: Kirigami.Units.smallSpacing

			Kirigami.Icon {
				source:  notificationData.appName.toLowerCase()||notificationData.appIcon||notificationData.image
				implicitWidth: Kirigami.Units.gridUnit
				implicitHeight: Kirigami.Units.gridUnit
			}

			Kirigami.Heading {
				Layout.fillWidth:true
			level: 2
			text: notificationData.appName
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
		contentItem:FormCard.FormButtonDelegate {
			id:notif
			icon.name:notificationData.image || notificationData.appIcon || notificationData.appName.toLowerCase()
			description:notificationData.body
			text: notificationData.summary
			// 设置卡片高亮样式（如果是紧急通知）
			background: Rectangle {
				color:  Qt.alpha(Kirigami.Theme.backgroundColor, 0.5)
				radius: Kirigami.Units.gridUnit / 3
				border.color: notificationData.urgency === 2 ? Kirigami.Theme.negativeTextColor : "transparent"
				border.width: 2
				layer.enabled: true
			}

			trailing: RowLayout {
				id: notifLayout
				spacing: Kirigami.Units.mediumSpacing

				// 2. 中间文字区域 (关键：必须 fillWidth 才能触发换行)
				RowLayout {
					ToolButton {
						icon.name: "view-more-symbolic"
						flat: true
						onClicked: {
							if (notificationData.actions.length > 0) {
								// 使用弹窗的父级或 Overlay 打开
								actionMenu.popup(notif, 0, notif.height)
							}
						}
					}
					Menu {
						id: actionMenu
						// 动态加载来自 notificationData 的 actions
						parent: Overlay.overlay
						Instantiator {
							model: notificationData.actions?notificationData.actions:[]
							onObjectAdded: (index, object) => actionMenu.insertItem(index, object)
							onObjectRemoved: (index, object) => actionMenu.removeItem(object)
							delegate: MenuItem {
								text: modelData.text
								icon.name: notificationData.hasActionIcons?modelData.identifier :"system-run-symbolic"
								onTriggered: {
									notificationData.invoke(modelData.id)
								}
							}
						}
					}
				}
			}
		   }
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
	function startExit() {
		exitAnim.start();
	}
}
