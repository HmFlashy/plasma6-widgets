import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_hideWhenSuspended: hideCheck.checked
    property alias cfg_intervalMs: intervalSpin.value
    property alias cfg_maxSamples: samplesSpin.value

    property alias cfg_showTemp: tempCheck.checked
    property alias cfg_showClock: clockCheck.checked
    property alias cfg_showUtil: utilCheck.checked
    property alias cfg_showVram: vramCheck.checked
    property alias cfg_showPower: powerCheck.checked

    property alias cfg_tempColor: tempColorField.text
    property alias cfg_clockColor: clockColorField.text
    property alias cfg_utilColor: utilColorField.text
    property alias cfg_vramColor: vramColorField.text
    property alias cfg_powerColor: powerColorField.text

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: hideCheck
            Kirigami.FormData.label: "Comportement :"
            text: "Masquer automatiquement quand le GPU est en veille"
        }

        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: "Rafraîchissement (ms) :"
            from: 500
            to: 10000
            stepSize: 250
        }

        QQC2.SpinBox {
            id: samplesSpin
            Kirigami.FormData.label: "Points d'historique :"
            from: 15
            to: 120
            stepSize: 5
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Graphiques affichés & couleurs"
        }

        RowLayout {
            Kirigami.FormData.label: "Température :"
            QQC2.CheckBox { id: tempCheck; text: "Afficher" }
            QQC2.TextField { id: tempColorField; maximumLength: 9; implicitWidth: 90 }
            Rectangle { width: 18; height: 18; radius: 3; color: tempColorField.text }
        }

        RowLayout {
            Kirigami.FormData.label: "Fréquence GPU :"
            QQC2.CheckBox { id: clockCheck; text: "Afficher" }
            QQC2.TextField { id: clockColorField; maximumLength: 9; implicitWidth: 90 }
            Rectangle { width: 18; height: 18; radius: 3; color: clockColorField.text }
        }

        RowLayout {
            Kirigami.FormData.label: "Utilisation (%) :"
            QQC2.CheckBox { id: utilCheck; text: "Afficher" }
            QQC2.TextField { id: utilColorField; maximumLength: 9; implicitWidth: 90 }
            Rectangle { width: 18; height: 18; radius: 3; color: utilColorField.text }
        }

        RowLayout {
            Kirigami.FormData.label: "VRAM (Mo) :"
            QQC2.CheckBox { id: vramCheck; text: "Afficher" }
            QQC2.TextField { id: vramColorField; maximumLength: 9; implicitWidth: 90 }
            Rectangle { width: 18; height: 18; radius: 3; color: vramColorField.text }
        }

        RowLayout {
            Kirigami.FormData.label: "Consommation (W) :"
            QQC2.CheckBox { id: powerCheck; text: "Afficher" }
            QQC2.TextField { id: powerColorField; maximumLength: 9; implicitWidth: 90 }
            Rectangle { width: 18; height: 18; radius: 3; color: powerColorField.text }
        }
    }
}
