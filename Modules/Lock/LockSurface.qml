import QtQuick
import Quickshell
import Quickshell.Wayland
import org.kde.kirigami as Kirigami
import QtQuick.Controls
import QtQuick.Layouts
import qs.Services
import qs.Config
import qs.Modules.Wallpaper.WallpaperContent
import Quickshell.Services.Pam

Kirigami.Page {
	signal unlocked();
	anchors.fill: parent
	background: LockWallpaper{}
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
					color:  Qt.alpha(Kirigami.Theme.disabledTextColor, 1)
				}
				Kirigami.Heading {
					font.pixelSize: Kirigami.Units.gridUnit * 12
					text: ":"
					color: Qt.alpha(Kirigami.Theme.textColor, 0.5)
				}
				Kirigami.Heading {
					font.pixelSize: Kirigami.Units.gridUnit * 12
					text: Time.minutes
					color:Qt.alpha(Kirigami.Theme.textColor, 0.5)
				}
			}

			// 日期
			RowLayout {
				Layout.alignment: Qt.AlignHCenter
				spacing: Kirigami.Units.smallSpacing
				Kirigami.Heading { text: Time.month; font.pixelSize: Kirigami.Units.gridUnit * 3; color:Qt.alpha(Kirigami.Theme.disabledTextColor, 1) }
				Kirigami.Heading { text: Time.day; font.pixelSize: Kirigami.Units.gridUnit * 3; color: Kirigami.Theme.textColor }
			}
		}
		Item {
			Layout.fillWidth: true
			Layout.fillHeight: true
			Layout.preferredHeight: 1
		}
		// --- 4. 底部(时钟下方) ---
		ColumnLayout {
			Layout.fillWidth: true

		LockContext{
			id:pam
			onSuccess:{
				unlocked()
			}
			onFailed:{
			}
			}
		}
		// --- 5. 底部弹性占位---
		// 权重设为 2，保证时钟上方空间:下方空间 = 1:2，即时钟在 1/3 处
		Item {
			Layout.fillWidth: true
			Layout.fillHeight: true
			Layout.preferredHeight: 8
		}
	}
	Timer {
		id: clockTimer
		interval: 10000 // 10秒
		repeat: false
		onTriggered: {
			clockContainer.visible=false
		}
	}
	MouseArea {
		anchors.fill: parent
		hoverEnabled: true
		onPositionChanged: {
			clockTimer.restart();
			clockContainer.visible=true
		}
		onClicked: {
			if (!pam.active) {
				pam.start();
			}
		}
	}
}


