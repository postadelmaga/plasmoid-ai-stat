import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: configGeneral

    property alias cfg_refreshInterval: refreshSlider.value
    property alias cfg_showCosts: showCostsCheck.checked
    property alias cfg_monthlyBudget: budgetSpinBox.value
    property alias cfg_dailyInputLimitM: inputLimitSpinBox.value
    property alias cfg_dailyOutputLimitM: outputLimitSpinBox.value
    property alias cfg_geminiApiKey: geminiKeyField.text
    property string cfg_compactStyle: "ring"

    Kirigami.FormLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Display")
        }

        QQC2.Slider {
            id: refreshSlider
            Kirigami.FormData.label: i18n("Refresh every %1s", Math.round(value))
            from: 60
            to: 900
            stepSize: 30
            Layout.fillWidth: true
        }

        QQC2.ComboBox {
            id: compactStyleCombo
            Kirigami.FormData.label: i18n("Panel indicator:")
            model: [
                { value: "ring", text: i18n("Quota ring") },
                { value: "tacho", text: i18n("Tachometer") }
            ]
            textRole: "text"
            valueRole: "value"
            currentIndex: cfg_compactStyle === "tacho" ? 1 : 0
            onActivated: cfg_compactStyle = currentValue
        }

        QQC2.CheckBox {
            id: showCostsCheck
            Kirigami.FormData.label: i18n("Show costs:")
            text: i18n("Display estimated cost info")
        }

        QQC2.SpinBox {
            id: budgetSpinBox
            Kirigami.FormData.label: i18n("Monthly budget ($):")
            from: 1
            to: 10000
            stepSize: 10
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Claude")
        }

        QQC2.Label {
            text: i18n("Tier auto-detected from ~/.claude/.credentials.json")
            wrapMode: Text.Wrap
            opacity: 0.6
            Layout.fillWidth: true
        }

        QQC2.SpinBox {
            id: inputLimitSpinBox
            Kirigami.FormData.label: i18n("Daily input limit (M tokens):")
            from: 0
            to: 9999
            stepSize: 10
        }

        QQC2.SpinBox {
            id: outputLimitSpinBox
            Kirigami.FormData.label: i18n("Daily output limit (M tokens):")
            from: 0
            to: 9999
            stepSize: 1
        }

        QQC2.Label {
            text: i18n("0 = auto-detect from tier. Override if limits seem wrong.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.6
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Gemini")
        }

        QQC2.TextField {
            id: geminiKeyField
            Kirigami.FormData.label: i18n("Gemini API Key:")
            placeholderText: "AIzaSy..."
            echoMode: TextInput.Password
            Layout.fillWidth: true
        }

        QQC2.Label {
            text: i18n("Get your key at ai.google.dev. Used to check rate limits.")
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.6
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }
}
