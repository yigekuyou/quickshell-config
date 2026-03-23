import QtQuick
import org.kde.kirigami as Kirigami
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.Widget.common
import qs.config
import qs.Widget.audio
import qs.Services

SlideWindow {
    id: root
    title: "混音器"
    icon:{
	    if (Volume.sinkVolume === 0 || Volume.sinkMuted) return "audio-volume-muted";
	    if (Volume.sinkVolume < 0.33) return "audio-volume-low";
	    if (Volume.sinkVolume < 0.66) return "audio-volume-medium";
	    return "audio-volume-high";
    }
    
    windowHeight: 360
    
    headerTools: Text {
        // 【修复1】这里需要 Theme 实例，因为 headerTools 是动态加载的
        Theme { id: theme }
        
        text: "\uf013"
        font.family: "Font Awesome 6 Free Solid"
        font.pixelSize: 18
        color: theme.subtext
        MouseArea { 
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Quickshell.execDetached([""])
        }
    }

    // --- Pipewire 逻辑 ---
    property var defaultSink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [ root.defaultSink ] }
    PwNodeLinkTracker { id: appTracker; node: root.defaultSink }
    
    function isHeadphone(node) {
        if (!node) return false;
        const icon = node.properties["device.icon-name"] || ""; 
        const desc = node.description || "";
        return icon.includes("headphone") || desc.toLowerCase().includes("headphone") || desc.toLowerCase().includes("耳机");
    }

    // --- 界面内容 ---
    
    // 1. 主音量卡片
    Kirigami.Card {
        Layout.fillWidth: true
        contentItem: ColumnLayout {
		spacing: Kirigami.Units.gridUnit
        implicitWidth: ListView.view.width
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
			source: isHeadphone(root.defaultSink) ? "audio-headphones" : "audio-speakers"
			implicitWidth: Kirigami.Units.iconSizes.smallMedium
			implicitHeight: Kirigami.Units.iconSizes.smallMedium
			color: Kirigami.Theme.highlightColor
		}
		Kirigami.Heading {
			level: 4
			text: root.defaultSink ? (root.defaultSink.description || root.defaultSink.name) : "未找到设备"
			Layout.fillWidth: true
			elide: Text.ElideRight
		}
		Label {
			text: root.defaultSink ? Math.round(root.defaultSink.audio.volume * 100) + "%" : "0%"
			font.bold: true
			color: Kirigami.Theme.highlightColor
		}
            }

            // 复用 VolumeSlider
            VolumeSlider { 
                node: root.defaultSink
                isHeadphone: root.isHeadphone(root.defaultSink)
            }
        }
    }

    // 2. 应用程序列表
    Kirigami.Separator {
	    Layout.fillWidth: true
	    visible: appTracker.linkGroups.length > 0
    }
    Label {
	    text: "正在播放的程序"
	    font: Kirigami.Theme.smallFont
	    opacity: 0.7
	    visible: appTracker.linkGroups.length > 0
    }

    ListView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        
        model: appTracker.linkGroups

        delegate: Rectangle {
		Layout.alignment: Qt.AlignCenter
            // 【修复2】这里必须实例化 Theme，否则下面的颜色找不到 theme 对象
            Theme { id: itemTheme }

            required property PwLinkGroup modelData
            property var appNode: modelData.source

            implicitWidth: ListView.view.implicitWidth
            implicitHeight: 50
            radius: 8
            color: "transparent"
            // 使用 itemTheme
            border.color: ma.containsMouse ? itemTheme.primary : "transparent"
            Behavior on border.color { ColorAnimation { duration: 150 } }

            PwObjectTracker { objects: [ appNode ] }

            ColumnLayout {
		    Layout.alignment: Qt.AlignCenter
            RowLayout {
                spacing: 12

                // 应用图标
                Kirigami.Icon {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    visible: source != ""
		    source: {
			    // 逻辑：优先取 icon-name，其次取节点名，最后保底
			    return (appNode.properties && appNode.properties["application.icon-name"])
			    || appNode.name }
			    fallback: "audio-volume-high-symbolic"
                }

                // 应用名称 + 音量条
                ColumnLayout {
                    Layout.fillWidth: true
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
				text: {
					const app = appNode.properties["application.name"] ?? (appNode.description || appNode.name);
					const media = appNode.properties["media.name"];
					return media ? `${app} - ${media}` : app;
				}
				elide: Text.ElideRight
				Layout.fillWidth: true
				font.bold: true
			}
			Label {
				text: `${Math.floor(appNode.audio.volume * 100)}%`
				font: Kirigami.Theme.smallFont
			}
                    }

                    // 迷你音量条
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        color: Qt.rgba(1, 1, 1, 0.1) // 半透明深色背景
			radius: height / 2

                        Rectangle {
				id:progressFill
                            height: parent.height
                            width: seekMa.pressed
                            ? Math.min(Math.max(0, seekMa.mouseX), parent.width)
			    : parent.width * appNode.audio.volume
                        radius: parent.radius

                        // 【关键修复】这里之前是白色，现在使用了 itemTheme.primary
                            color: Kirigami.Theme.highlightColor
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

                        MouseArea {
				id:seekMa
				hoverEnabled: true
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onPressed:{
				    let pos = Math.min(Math.max(0, mouse.x / parent.width), 1.0);
				    appNode.audio.volume = pos
			    }
			    onReleased: {
					    let pos = Math.min(Math.max(0, mouse.x / parent.width), 1.0);
					    appNode.audio.volume = pos
			    }
			    onPositionChanged: (mouse) => {
				    if (pressed) {
					    let pos = Math.min(Math.max(0, mouse.x / parent.width), 1.0);
					    appNode.audio.volume = pos
				    }
			    }
                        }
                    }
                }
                Button {
			display: AbstractButton.IconOnly
			icon.name: appNode.audio.muted ? "audio-volume-muted" : "audio-volume-high"
			flat: true
			onClicked: appNode.audio.muted = !appNode.audio.muted
			icon.color: node.audio.muted ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
			ToolTip.delay: Kirigami.Units.toolTipDelay
			ToolTip.visible: hovered
			ToolTip.text: appNode.audio.muted ? "解除静音" : "静音"
		}
            }
        }
	}
	Kirigami.PlaceholderMessage {
		visible: appTracker.linkGroups.length === 0
		text: "没有正在播放音频的应用"
		icon.name: "audio-volume-muted"
	}
    }
}
