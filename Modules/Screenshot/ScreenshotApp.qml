import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Item {
	id: container
	property bool lockLoader: false

	IpcHandler {
		target: "shot"
		function open() {
			container.lockLoader = true
		}
	}

	LazyLoader {
		activeAsync: container.lockLoader

		FloatingWindow {
			id: root
			title: "Quickshell 截图工具"
			color: Kirigami.Theme.backgroundColor

			Kirigami.Page {
				anchors.fill: parent
				title: "窗口捕捉预览"

				actions: [
					Kirigami.Action {
						icon.name: "view-refresh"
						text: "刷新预览"
						onTriggered: { if (screenshotView.captureSource) screenshotView.captureFrame(); }
					},
					Kirigami.Action {
						icon.name: "window-close"
						text: "关闭"
						onTriggered: container.lockLoader = false
					}
				]

				ColumnLayout {
					anchors.fill: parent
					spacing: Kirigami.Units.largeSpacing

					// --- 顶部控制栏 ---
					Kirigami.FormLayout {
						Layout.fillWidth: true

						ComboBox {
							id: windowSelector
							// 确保附加属性单独占行或正确分隔
							Kirigami.FormData.label: "目标窗口"
							Layout.fillWidth: true

							model: ToplevelManager.toplevels
							textRole: "title"

							// 修复显示逻辑
							displayText: {
								var item = windowSelector.model[windowSelector.currentIndex];
								return item ? (item.title || item.appId || "未命名窗口") : "请选择窗口";
							}

							// 修正后的 Delegate
							delegate: ItemDelegate {
								width: windowSelector.width
								contentItem: ColumnLayout {
									spacing: 2
									Label {
										text: (modelData.title || "无标题窗口")
										font.bold: windowSelector.currentIndex === index
										elide: Text.ElideRight
									}
									Label {
										text: modelData.appId || "Unknown ID"
										font.pointSize: Kirigami.Theme.smallFont.pointSize
										color: Kirigami.Theme.disabledTextColor
										elide: Text.ElideRight
									}
								}
								highlighted: windowSelector.highlightedIndex === index
								onClicked: {
									windowSelector.currentIndex = index;
									screenshotView.captureSource = modelData;
									windowSelector.popup.close();
										screenshotView.live = false; // 关闭实时流
										screenshotView.captureFrame(); // 触发单帧捕捉
								}
							}
						}
					}

					// --- 中间：预览区 ---
					Kirigami.Card {
						Layout.fillWidth: true
						Layout.fillHeight: true

						// 卡片内部背景
						background: Rectangle {
							color: Kirigami.Theme.alternateBackgroundColor
							radius: Kirigami.Units.smallSpacing
						}

						contentItem: Item {
							clip: true
							ScreencopyView {
								id: screenshotView
								anchors.centerIn: parent
								constraintSize: Qt.size(parent.width - 20, parent.height - 20)
								captureSource: (ToplevelManager.toplevels.length > 0) ? ToplevelManager.toplevels[0] : null
								live: false
								paintCursor: true
							}

							Label {
								anchors.centerIn: parent
								text: "等待窗口流..."
								visible: !screenshotView.captureSource
								color: Kirigami.Theme.disabledTextColor
							}
						}
					}

					// --- 底部状态栏 ---
					Kirigami.InlineMessage {
						Layout.fillWidth: true
						visible: screenshotView.captureSource !== null
						type: Kirigami.MessageType.Information
						text: {
							var win = screenshotView.captureSource;
							if (!win) return "未连接";
							return "应用: " + win.appId + " | 状态: " + (win.activated ? "活跃" : "空闲");
						}
					}
				}
			}
		}
	}
}
