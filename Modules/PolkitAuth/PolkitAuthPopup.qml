//PolkitAuthPopup.qml
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import Quickshell
import Quickshell.Services.Polkit

Kirigami.Card {
    property var authFlow: null

    anchors.fill: parent
    anchors.margins: Kirigami.Units.smallSpacing

    background: Rectangle {
        color: Kirigami.Theme.backgroundColor
        radius: Kirigami.Units.gridUnit / 3
        border.color: authFlow && authFlow.failed ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.focusColor
        border.width: 1
    }

    ColumnLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        // 1. 标题与图标
        RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon {
                source: (authFlow.iconName) ? authFlow.iconName : "dialog-password"
                Layout.preferredWidth: Kirigami.Units.iconSizes.large
                Layout.preferredHeight: Kirigami.Units.iconSizes.large
            }
            Label {
                text: authFlow ? authFlow.message : "系统认证"
                font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // 2. 身份选择
        ComboBox {
            visible: authFlow && authFlow.identities.length > 1
            Layout.fillWidth: true
            model: authFlow ? authFlow.identities : []
            onActivated: index => {
                authFlow.selectedIdentity = authFlow.identities[index];
            }
        }

        // 3. 密码输入区
        ColumnLayout {
            Layout.fillWidth: true
            visible: authFlow && authFlow.isResponseRequired

            Label {
                text: authFlow ? authFlow.inputPrompt : "Password:"
                font: Kirigami.Theme.smallFont
            }

            TextField {
                id: passwordField
                Layout.fillWidth: true
                echoMode: (authFlow && authFlow.responseVisible) ? TextInput.Normal : TextInput.Password
                focus: true
                placeholderText: "输入密码后按回车..."
                onAccepted: {
                    if (authFlow)
                        authFlow.submit(text);
                }
            }
        }

        // 4. 底部按钮与错误消息
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                text: authFlow ? authFlow.supplementaryMessage : ""
                visible: text !== ""
                type: (authFlow && authFlow.supplementaryIsError) ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                Button {
                    text: "取消"
                    onClicked: {
                        if (authFlow)
                            authFlow.cancelAuthenticationRequest();
                        startExit();
                    }
                }
                Button {
                    text: "确定"
                    highlighted: true
                    onClicked: {
                        if (authFlow)
                            authFlow.submit(passwordField.text);
                    }
                }
            }
        }
    }

    // 自动监听成功状态关闭窗口
    Connections {
        target: authFlow
        function onIsSuccessfulChanged() {
            if (authFlow && authFlow.isSuccessful)
                startExit();
        }
        function onIsCancelledChanged() {
            if (authFlow && authFlow.isCancelled)
                startExit();
        }
        function onFailedChanged() {
            if (authFlow && authFlow.failed) {
                passwordField.clear();
                // 可以在这里触发一个抖动动画
            }
        }
    }
}
