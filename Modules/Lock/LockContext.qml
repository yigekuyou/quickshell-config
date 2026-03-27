import QtQuick
import Quickshell
import Quickshell.Services.Pam
import org.kde.kirigami as Kirigami
import QtQuick.Controls
import QtQuick.Layouts

Kirigami.FormLayout{
    signal success()
    signal failed()
    signal start()
    property bool active: passwordField.visible

    onFailed:{
	    failureLabel.opacity = 1
    }
    onStart:{
	    if (!pam.active) {
		    pam.start();
	    }
	    passwordField.forceActiveFocus();
	    failureLabel.opacity = 0
	}
    PamContext {
        id: pam
        // 指向 pam 文件夹的绝对路径
        configDirectory: Quickshell.env("HOME") + "/.config/quickshell/Modules/Lock/pam"
        config: "password.conf"

        onPamMessage: {
            if (responseRequired) {
            }
        }

        onCompleted: result => {
            if (result == PamResult.Success) {
		    success()
            } else {
		    failed();
                passwordField.text = ""; // 清空密码
            }
        }
    }
    Kirigami.FormLayout {
	    Kirigami.Heading {
		    id: failureLabel
		    text: "认证失败，请重试"
		    color: Kirigami.Theme.negativeTextColor // 使用主题的红色
		    font.pixelSize: Kirigami.Units.gridUnit * 1.5
		    Layout.alignment: Qt.AlignHCenter
		    opacity: 0 // 默认隐藏

		    // 简单的渐变动画
		    Behavior on opacity { NumberAnimation { duration: 200 } }
	    }
	    TextField {
		    id: passwordField
		    enabled:pam.active
		    visible: pam.active
		    echoMode: TextInput.Password
		    placeholderText: pam.message
		    background: Rectangle {
			    color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.5)
		    }
		    Keys.onEscapePressed: {
			    pam.abort();
		    }
		    onAccepted: {
			    pam.respond(text);
			    text=""; // 擦除
		    }
	    }
    }
}
