import QtQuick
import Quickshell
import qs.Services
import qs.Config
import qs.Widget
import qs.Modules.Bar.common
import org.kde.kirigami as Kirigami

// 顶栏音量入口：图标随音量/耳机状态变，滚轮直接调音量，点击开混音器面板。
// 外观与交互全部交给 qs.Modules.Bar.common.BarButton。
BarButton {
    id: root

    readonly property bool muted: Volume.sinkMuted || Volume.sinkVolume <= 0

    icon: Volume.isHeadphone ? "audio-headphones" : (root.muted ? "audio-volume-muted" : (Volume.sinkVolume < 0.33 ? "audio-volume-low" : (Volume.sinkVolume < 0.66 ? "audio-volume-medium" : "audio-volume-high")))
    iconSize: Kirigami.Units.gridUnit
    text: Math.round(Volume.sinkVolume * 100) + "%"
    textBold: true
    contentColor: root.muted ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.activeTextColor
    checked: audioPanel.visible

    // 滚轮：BarButton 里的 WheelHandler 只发信号，改值留在消费方
    scrollEnabled: true
    onScrolled: delta => Volume.setSinkVolume(Volume.sinkVolume + delta)

    onClicked: audioPanel.visible = !audioPanel.visible

    AudioWidget {
        id: audioPanel
        anchorItem: root
        visible: false
    }
        MouseArea {
        anchors.fill: parent
        onWheel: wheel => {
            const step = 0.05;
            let newVol = Volume.sinkVolume;

            if (wheel.angleDelta.y > 0)
                newVol += step;
            else
                newVol -= step;
            Volume.setSinkVolume(newVol);
        }
    }
}