import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.config

Item {
	id: root
	signal launchRequested()

	// 存储所有从系统获取的应用条目
	property var allEntries: []
	// 过滤后的显示列表
	property var filteredEntries: []
	property bool isLoading: true
	property string searchText: ""
	Component.onCompleted: {
		// 直接获取系统所有的桌面入口
		// DesktopEntries.entries 返回的是 DesktopEntry 对象的列表
		allEntries = DesktopEntries.entries.filter(entry => {
			// 过滤掉标记为 NoDisplay 的条目
			return !entry.noDisplay;
		});

		// 初始显示全部
		updateFilter();
		isLoading = false;
	}

	// 监听搜索文本变化
	onSearchTextChanged: updateFilter()

	function updateFilter() {
		if (searchText.trim() === "") {
			filteredEntries = allEntries;
		} else {
			let searchLower = searchText.toLowerCase();
			filteredEntries = allEntries.filter(entry => {
				return entry.name.toLowerCase().includes(searchLower) ||
				(entry.comment && entry.comment.toLowerCase().includes(searchLower));
			});
		}
	}

	ColumnLayout {
		anchors.fill: parent
		spacing: 10

		// 搜索框（假设由父组件或外部传入 searchText）
		// 这里仅展示列表逻辑

		ListView {
			id: appsList
			Layout.fillWidth: true
			Layout.fillHeight: true
			model: filteredEntries
			clip: true
			spacing: 4

			delegate: ItemDelegate {
				width: ListView.view.width
				height: 50

				// 点击运行应用
				onClicked: runEntry(modelData)

				contentItem: RowLayout {
					spacing: 12

					// 应用图标
					// DesktopEntry.icon 通常返回图标名称或路径
					Image {
						Layout.preferredWidth: 32
						Layout.preferredHeight: 32
						source: {
							if (!modelData.icon) return "";
							// 如果是路径则直接使用，否则使用 icon 协议
							return modelData.icon.startsWith("/") ? "file://" + modelData.icon : "image://icon/" + modelData.icon;
						}
					}

					// 应用名称
					Text {
						text: modelData.name
						color: Colorscheme.on_surface
						font.pixelSize: 15
						Layout.fillWidth: true
						elide: Text.ElideRight
					}
				}
			}
		}
	}

	// 运行选中的应用
	function runEntry(entry) {
		if (entry) {
			// DesktopEntry.launch() 是 Quickshell 提供的快捷方法
			// 它会自动处理执行路径和参数
			entry.launch();
			root.launchRequested();
		}
	}

	// 处理回车运行第一项
	function runSelectedApp() {
		if (filteredEntries.length > 0 && appsList.currentIndex >= 0) {
			runEntry(filteredEntries[appsList.currentIndex]);
		}
	}
}
