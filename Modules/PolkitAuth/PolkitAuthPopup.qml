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
                color: Kirigami.Theme.textColor
            }
            Kirigami.Heading {
                text: authFlow?.message || qsTr("需要身份认证")
                level: 3
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
        Kirigami.FormLayout {
		Layout.fillWidth: true
		Kirigami.Heading {
			visible: authFlow && authFlow.identities.length === 1
			text:   qsTr("认证身份") +":"+authFlow.selectedIdentity.displayName
			level: 1
			color: Kirigami.Theme.highlightColor
			Layout.fillWidth: true
		}
		// 身份选择
		ComboBox {
			Kirigami.FormData.label: qsTr("认证身份")
			visible: authFlow && authFlow.identities.length > 1
			Layout.fillWidth: true
			model: authFlow ? authFlow.identities : []
			textRole: "displayName"
			valueRole: "id"
			enabled: model.length > 1
			onActivated: index => {
				authFlow.selectedIdentity = authFlow.identities[index];
			}
		}

		// 密码输入
		TextField {
			id: passwordField
			Kirigami.FormData.label:(authFlow?.inputPrompt || qsTr("密码:"))
			visible: authFlow?.isResponseRequired || false
			Layout.fillWidth: true
			echoMode: (authFlow && authFlow.responseVisible) ? TextInput.Normal : TextInput.Password
			focus: true
			placeholderText:qsTr("请输入密码")

			onAccepted: if (authFlow) authFlow.submit(text)

			// 自动聚焦
			Component.onCompleted: forceActiveFocus()
		}
	}

	// 3. 错误消息
	Kirigami.InlineMessage {
		Layout.fillWidth: true
		text: authFlow?.supplementaryMessage || ""
		visible: text !== ""
		type: (authFlow && authFlow.supplementaryIsError) ? Kirigami.MessageType.Error : Kirigami.MessageType.Information
		showCloseButton: false
	}

	// 4. 操作按钮
	RowLayout {
		Layout.alignment: Qt.AlignRight
		spacing: Kirigami.Units.smallSpacing

		Button {
			text: "取消"
			icon.name: "dialog-cancel"
			onClicked: {
				authFlow?.cancelAuthenticationRequest();
			}
		}

		Button {
			text: "确定"
			icon.name: "dialog-ok-apply"
			highlighted: true
			enabled: !authFlow?.isProcessing // 防止重复提交
			onClicked: {
				if (authFlow) authFlow.submit(passwordField.text);
			}
		}
	}
    }

    // 状态逻辑处理
    Connections {
	    target: authFlow
	    ignoreUnknownSignals: true
	    function onFailedChanged() {
		    if (authFlow && authFlow.failed) {
			    passwordField.clear();
			    passwordField.forceActiveFocus();
		    }
	    }
    }
}
