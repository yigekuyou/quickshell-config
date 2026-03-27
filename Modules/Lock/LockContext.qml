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

    onStart:{
	    if (!pam.active) {
		    pam.start();
	    }
	    passwordField.forceActiveFocus();
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
	    TextField {
		    id: passwordField
		    enabled:true
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
