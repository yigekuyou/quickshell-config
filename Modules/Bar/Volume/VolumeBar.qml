import QtQuick
import Quickshell
import org.kde.kirigami as Kirigami
import qs.Config
import qs.Modules.Bar.common
import qs.Services
import qs.Widget

// 顶栏音量入口：图标随音量/耳机状态变，滚轮直接调音量，点击开混音器面板。
// 外观与交互全部交给 qs.Modules.Bar.common.BarButton。
BarButton {
    id: root

    readonly property bool muted: Volume.sinkMuted || Volume.sinkVolume <= 0

    section: "right"
    icon: Volume.isHeadphone ? "audio-headphones" : (root.muted ? "audio-volume-muted" : (Volume.sinkVolume < 0.33 ? "audio-volume-low" : (Volume.sinkVolume < 0.66 ? "audio-volume-medium" : "audio-volume-high")))
    text: Math.round(Volume.sinkVolume * 100) + "%"
    textBold: true
    progress: Sizes.barRing ? Volume.sinkVolume : -1
    contentColor: root.muted ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.activeTextColor
    checked: audioPanel.visible
    // 滚轮：BarButton 里的 WheelHandler 只发信号，改值留在消费方
    onScrolled: (delta) => {
        return Volume.setSinkVolume(Volume.sinkVolume + delta);
    }
    onClicked: audioPanel.visible = !audioPanel.visible

    AudioWidget {
        id: audioPanel

        anchorItem: root
        visible: false
    }

    MouseArea {
        z: -1
        anchors.fill: parent
        onWheel: (wheel) => {
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
