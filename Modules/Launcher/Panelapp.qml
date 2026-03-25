import org.kde.kirigami as Kirigami
import QtQuick.Controls
import qs.config
import qs.Services
import QtQuick
import QtQuick.Layouts
Kirigami.ShadowedRectangle {
	anchors {
		fill: parent
	}
	radius: Kirigami.Units.gridUnit / 2
	color: Qt.alpha(Kirigami.Theme.backgroundColor,0.5)
	shadow.color: Qt.alpha(0, 0, 0, 0.2)

	implicitWidth:(Kirigami.Units.iconSizes.medium+Kirigami.Units.gridUnit )*TaskbarApps.apps.length
	implicitHeight:Kirigami.Units.iconSizes.medium+Kirigami.Units.gridUnit
	RowLayout {
		anchors.fill: parent
		anchors.leftMargin: Kirigami.Units.smallSpacing
		anchors.rightMargin: Kirigami.Units.smallSpacing
		spacing: Kirigami.Units.smallSpacing
		Repeater {
			model: TaskbarApps.apps

			delegate: Kirigami.AbstractCard {
				id: appDelegate
				implicitWidth: Kirigami.Units.gridUnit * 2
				Layout.fillHeight: true
				Layout.fillWidth: true

				// 移除卡片默认边距和背景，手动控制
				showClickFeedback: true
				highlighted: hovered
				ToolTip.delay: Kirigami.Units.toolTipDelay
				background: Rectangle {
					color: appDelegate.hovered ?Qt.alpha(Kirigami.Theme.hoverColor,0.2)  : "transparent"
					// 运行中状态指示器
				}

				contentItem: Kirigami.Icon {
					source: modelData.appId
					opacity: modelData.toplevels.length > 0 ? 1.0 : 0.6 // 未运行时图标半透明
					scale: appDelegate.pressed ? 0.9 : (appDelegate.hovered ? 1.1 : 1.0)
					Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration } }
				}
				onClicked: {
					const wins = modelData.toplevels;
					const count = wins.length;

					if (count > 0) {
						// 1寻找当前处于激活状态的窗口索引
						let activeIndex = -1;
						for (let i = 0; i < count; i++) {
							if (wins[i].activated === true) {
								activeIndex = i;
								break;
							}
						}

						// 2. 执行切换逻辑
						if (activeIndex !== -1) {
							// 情况 A：该应用的某个窗口正处于激活状态
							if (count === 1) {
								// 只有一个窗口时，点击则最小化
								wins[0].minimized = true;
							} else {
								// 有多个窗口，按顺序切换到下一个 (Index + 1)
								let nextIndex = (activeIndex + 1) % count;
								let nextWin = wins[nextIndex];

								nextWin.activate(); // 调用文档中的 activate() 函数
								if (nextWin.minimized) nextWin.minimized = false;
							}
						} else {
							// 情况 B：当前没有窗口被激活
							// 默认激活第一个，如果它被最小化了则恢复
							wins[0].activate();
							if (wins[0].minimized) wins[0].minimized = false;
						}
					}
				}
			}
		}
		// 撑开右侧空间
		Item { Layout.fillWidth: true }
	}
}
