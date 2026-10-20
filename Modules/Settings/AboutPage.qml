import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Config
import qs.Services
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// 关于 / 配置文件位置。手改 json 后点「重新载入」即可生效（不用重启 qs）。
SettingsPage {
    id: root

    title: qsTr("关于")
    icon: "help-about"

    readonly property var entries: [
        {
            "label": qsTr("设置"),
            "path": Settings.path,
            "note": qsTr("全部可调参数的唯一来源")
        },
        {
            "label": "cava",
            "path": Directories.cavaConfigFile,
            "note": qsTr("顶栏频谱条（cava 自己读取）")
        },
        {
            "label": qsTr("配置目录"),
            "path": Directories.configDir,
            "note": qsTr("本 shell 的 QML 与资源")
        }
    ]

    FormCard.FormCard {
        Layout.fillWidth: true

        Repeater {
            model: root.entries

            delegate: FormCard.AbstractFormDelegate {
                id: entryRow

                required property var modelData

                Layout.fillWidth: true
                background: null

                contentItem: RowLayout {
                    spacing: Kirigami.Units.mediumSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Label {
                            text: entryRow.modelData.label
                            font.weight: Font.DemiBold
                            color: Kirigami.Theme.textColor
                        }

                        Label {
                            Layout.fillWidth: true
                            text: entryRow.modelData.path
                            elide: Text.ElideMiddle
                            maximumLineCount: 1
                            font.family: Sizes.fontFamilyMono
                            font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.62)
                            color: Kirigami.Theme.highlightColor
                        }

                        Label {
                            Layout.fillWidth: true
                            text: entryRow.modelData.note
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.62)
                            color: Kirigami.Theme.disabledTextColor
                        }
                    }

                    ToolButton {
                        onClicked: Quickshell.execDetached(["xdg-open", entryRow.modelData.path])
                        contentItem: Kirigami.Icon {
                            source: "document-open"
                            color: Kirigami.Theme.textColor
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: implicitWidth
                        }
                    }
                }
            }
        }
    }

    FormCard.FormCard {
        Layout.fillWidth: true

        FormCard.AbstractFormDelegate {
            Layout.fillWidth: true
            background: null

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Label {
                        text: Settings.ready ? qsTr("配置已载入") : qsTr("配置尚未载入")
                        font.weight: Font.DemiBold
                        color: Settings.ready ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
                    }

                    Label {
                        Layout.fillWidth: true
                        text: qsTr("手改 json 后重新载入即可生效；本窗口里的修改会自动保存。")
                        wrapMode: Text.WordWrap
                        font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.62)
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                Button {
                    text: qsTr("重新载入")
                    onClicked: Settings.reload()
                }
            }
        }
    }

    Label {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.smallSpacing
        text: qsTr("配置由 Services/Settings.qml 读写；设置窗口不占顶栏位置，")
            + qsTr("用 qs ipc call settings toggle 或全局快捷键 quickshell:settings 打开。")
        wrapMode: Text.WordWrap
        font.pixelSize: Math.round(Kirigami.Units.gridUnit * 0.62)
        color: Kirigami.Theme.disabledTextColor
    }
}