import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.config
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import QtQuick.Effects
Kirigami.Card {
    id: root
    background: Rectangle {
	    color: "transparent"
	    radius: Kirigami.Units.gridUnit

	    // 如果你希望完全透明，直接用 color: "transparent"

    }

    required property var player

    readonly property bool isActive: root.visible && root.player

    property string artUrl: (isActive && player.trackArtUrl) ? player.trackArtUrl : ""
    property string title: (isActive && player.trackTitle) ? player.trackTitle : "No Media"
    property string artist: (isActive && player.trackArtist) ? player.trackArtist : ""

    // 进度百分比 (0.0 ~ 1.0)
    property double progress: (isActive && player.length > 0) ? (player.position / player.length) : 0
    padding: Kirigami.Units.largeSpacing
    contentItem: ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        // --- 顶部信息栏 (封面 + 歌名) ---
        RowLayout {
            Layout.fillWidth: true

            spacing: Kirigami.Units.largeSpacing

            // 专辑封面
            Kirigami.ShadowedRectangle {
		    Layout.preferredWidth: Kirigami.Units.gridUnit * 3
		    Layout.preferredHeight: Kirigami.Units.gridUnit * 3
		    radius: Kirigami.Units.smallSpacing
		    color: Kirigami.Theme.backgroundColor

                Image {
                    anchors.fill: parent
                    source: root.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: root.artUrl !== "" && status === Image.Ready
                }

                // 没封面时显示的图标
                Kirigami.Icon {
			anchors.centerIn: parent
			width: 32; height: 32
			source: "audio-x-generic"
			visible: root.artUrl === ""
		}
            }

            // 文本信息
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                Kirigami.Heading {
			text: root.title
			level: 2
			Layout.fillWidth: true
			elide: Text.ElideRight
			type: Kirigami.Heading.Type.Primary
		}
                Label {
                    text: root.artist
                    color: "#aaa"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    Layout.fillWidth: true
                    opacity: 0.7
                    elide: Text.ElideRight
                }
            }
        }
        Item {
		id: progressBarContainer
		Layout.fillWidth: true
		Layout.preferredHeight: 16 // 增加感应区域高度，方便手指/鼠标操作

		Rectangle {
			id: trackBg
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			height: 6
			color: Qt.rgba(1, 1, 1, 0.1) // 半透明深色背景
			radius: height / 2

			// 进度填充 (白色条)
			Rectangle {
				id: progressFill
				height: parent.height
				radius: parent.radius
				color: "white"
				width: {
					if (seekMa.pressed && player.canSeek) {
						// 拖动时：强制跟随鼠标，限制在 0 到 总宽 之间
						return Math.min(Math.max(0, seekMa.mouseX), trackBg.width)
					}
					// 播放时：根据百分比计算宽度
					return root.progress * trackBg.width
				}
			}

			Rectangle {
				x: progressFill.width - width / 2
				anchors.verticalCenter: parent.verticalCenter
				width: 12; height: 12
				radius: 6
				color: "white"
				visible: seekMa.containsMouse || seekMa.pressed

				// 给小圆点加个简单的阴影或缩放效果
				scale: seekMa.pressed ? 1.2 : 1.0
				Behavior on scale { NumberAnimation { duration: 100 } }
			}
		}

		// 交互区域
		MouseArea {
			id: seekMa
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: player.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor

			onClicked: {
				if (player.canSeek) {
					// 计算点击位置占总长的比例
					let pos = Math.min(Math.max(0, mouseX / trackBg.width), 1.0)
					// 执行跳转： player.length * 比例
					player.position = pos * player.length
				}
			}

			onPositionChanged: {
				if (pressed && player.canSeek) {
					// 实时拖动时不需要立即给 player 发送 position（防止性能损耗或爆音）
					// 宽度会通过上面的 binding 自动更新
				}
			}

			onReleased: {
				if (player.canSeek) {
					let pos = Math.min(Math.max(0, mouseX / trackBg.width), 1.0)
					player.position = pos * player.length
				}
			}
		}
	}
        // --- 控制按钮 (上一曲/暂停/下一曲) ---
            RowLayout {
		Layout.fillWidth: true
		Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.gridUnit *2
                Button {
			implicitWidth: Kirigami.Units.gridUnit * 2
			implicitHeight: Kirigami.Units.gridUnit * 2
			icon.width: Kirigami.Units.gridUnit * 1.2
			icon.height: Kirigami.Units.gridUnit * 1.2
			flat: true
			icon.name: "media-skip-backward-symbolic"
			onClicked: if(root.player) root.player.previous()
			display: AbstractButton.IconOnly
			ToolTip.visible: hovered
			ToolTip.text: "上一首"
		}

		Button {
			flat: true
			// 增大播放按钮
			icon.width: Kirigami.Units.gridUnit * 2
			icon.height: Kirigami.Units.gridUnit * 2
			icon.name: (root.player && root.player.isPlaying)
			? "media-playback-pause-symbolic"
			: "media-playback-start-symbolic"
			onClicked: if(root.player) root.player.togglePlaying()
			display: Controls.AbstractButton.IconOnly
			ToolTip.visible: hovered
			ToolTip.text: (root.player && root.player.isPlaying) ? "暂停" : "播放"
		}

		Button {
			implicitWidth: Kirigami.Units.gridUnit * 2
			implicitHeight: Kirigami.Units.gridUnit * 2
			icon.width: Kirigami.Units.gridUnit * 1.2
			icon.height: Kirigami.Units.gridUnit * 1.2
			flat: true
			icon.name: "media-skip-forward-symbolic"
			onClicked: if(root.player) root.player.next()
			display: AbstractButton.IconOnly
			ToolTip.visible: hovered
			ToolTip.text: "下一首"
		}
            }
        }
}
