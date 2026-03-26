import QtQuick
import Quickshell
import Quickshell.Wayland
import org.kde.kirigami as Kirigami
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services
import qs.config
import qs.Modules.Wallpaper.WallpaperContent

Kirigami.Page {
	anchors.fill: parent
	background: Rectangle {
		color: Kirigami.Theme.backgroundColor
		// 这里可以添加背景图片或模糊效果
		Wallpaper{}

	}
	ColumnLayout {
		anchors.fill: parent
		spacing: 0 // 建议设为0，通过内部子项的 Layout.margins 控制间距

		// ---  顶部 (最上面) ---
		RowLayout {
			Layout.fillWidth: true
			// 这里放你的组件...
		}

		// --- 顶部弹性占位 (权重: 1) ---
		Item {
			Layout.fillWidth: true
			Layout.fillHeight: true
			Layout.preferredHeight: 1
		}

		// --- 时钟内容块 ---
		ColumnLayout {
			id: clockContainer
			Layout.fillWidth: true
			Layout.alignment: Qt.AlignHCenter
			spacing: -Kirigami.Units.gridUnit // 适当负间距让日期靠拢

			// 时:分
			RowLayout {
				Layout.alignment: Qt.AlignHCenter
				spacing: 0
				Kirigami.Heading {
					font.pixelSize: Kirigami.Units.gridUnit * 12
					text: Time.hours
					color: Kirigami.Theme.disabledTextColor
				}
				Kirigami.Heading {
					font.pixelSize: Kirigami.Units.gridUnit * 12
					text: ":"
					color: Kirigami.Theme.textColor
				}
				Kirigami.Heading {
					font.pixelSize: Kirigami.Units.gridUnit * 12
					text: Time.minutes
					color: Kirigami.Theme.textColor
				}
			}

			// 日期
			RowLayout {
				Layout.alignment: Qt.AlignHCenter
				spacing: Kirigami.Units.smallSpacing
				Kirigami.Heading { text: Time.month; level: 2; color: Kirigami.Theme.disabledTextColor }
				Kirigami.Heading { text: Time.day; level: 2; color: Kirigami.Theme.textColor }
			}
		}

		// --- 4. 底部(时钟下方) ---
		ColumnLayout {
			Layout.fillWidth: true
			// 这里放你的组件...
		}

		// --- 5. 底部弹性占位---
		// 权重设为 2，保证时钟上方空间:下方空间 = 1:2，即时钟在 1/3 处
		Item {
			Layout.fillWidth: true
			Layout.fillHeight: true
			Layout.preferredHeight: 2
		}
	}
}


