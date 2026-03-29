import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api
import "../charts"
import "../components"

Flickable {
    id: geminiTab

    required property var appRoot

    contentWidth: width
    contentHeight: geminiCol.implicitHeight + Kirigami.Units.largeSpacing
    clip: true
    flickableDirection: Flickable.VerticalFlick
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: scrollBar; policy: QQC2.ScrollBar.AsNeeded }

    ColumnLayout {
        id: geminiCol
        width: parent.width - Kirigami.Units.smallSpacing - (scrollBar.visible ? scrollBar.width : 0)
        spacing: Kirigami.Units.mediumSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing
            PlasmaComponents.Label {
                text: {
                    var p = appRoot.geminiPlan.charAt(0).toUpperCase() + appRoot.geminiPlan.slice(1)
                    return p.replace(/-/g, " ").replace("Pay as you go", "Pay-as-you-go")
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.5; Layout.fillWidth: true
            }
            QQC2.BusyIndicator {
                running: appRoot.geminiLoading; visible: appRoot.geminiLoading
                Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.ToolButton { icon.name: "view-refresh"; onClicked: appRoot.refreshAll() }
        }

        // No API key
        PlasmaComponents.Label {
            visible: appRoot.geminiApiKey === ""
            text: i18n("Add your Gemini API key in widget settings.")
            wrapMode: Text.Wrap; opacity: 0.6; Layout.fillWidth: true; Layout.margins: Kirigami.Units.largeSpacing; horizontalAlignment: Text.AlignHCenter
        }

        // Error
        PlasmaComponents.Label {
            visible: appRoot.geminiError !== ""; text: appRoot.geminiError
            color: Kirigami.Theme.negativeTextColor; wrapMode: Text.Wrap; Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing
        }

        // Rate limited warning
        PlasmaComponents.Label {
            visible: appRoot.geminiRateLimited
            text: i18n("Rate limited! Quota exhausted.")
            color: Kirigami.Theme.negativeTextColor; font.weight: Font.DemiBold
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; Layout.margins: Kirigami.Units.smallSpacing
        }

        // Quota Rings
        ColumnLayout {
            visible: appRoot.geminiOk; Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Rate Limits") }
            DualQuotaRing {
                Layout.alignment: Qt.AlignHCenter
                width: Kirigami.Units.gridUnit * 8; height: Kirigami.Units.gridUnit * 8
                outerUsed: appRoot.geminiReqLimit - appRoot.geminiReqRemaining; outerLimit: appRoot.geminiReqLimit; outerLabel: "req"
                outerColor: outerPct > 0.9 ? Kirigami.Theme.negativeTextColor : outerPct > 0.7 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.highlightColor
                innerUsed: appRoot.geminiTokLimit - appRoot.geminiTokRemaining; innerLimit: appRoot.geminiTokLimit; innerLabel: "tok"
                innerColor: innerPct > 0.9 ? Kirigami.Theme.negativeTextColor : innerPct > 0.7 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor
            }
        }

        // Stats cards
        GridLayout {
            visible: appRoot.geminiOk; Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing
            columns: 2; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
            StatCard { label: i18n("Requests"); value: appRoot.geminiReqRemaining.toString(); sub: i18n("remaining"); accent: Kirigami.Theme.highlightColor; Layout.fillWidth: true }
            StatCard { label: i18n("Tokens"); value: Api.formatTokens(appRoot.geminiTokRemaining); sub: i18n("remaining"); accent: Kirigami.Theme.positiveTextColor; Layout.fillWidth: true }
        }

        // Available Models
        ColumnLayout {
            visible: appRoot.geminiModels.length > 0; Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Available Models") }
            Repeater {
                model: appRoot.geminiModels
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: modelInfoCol.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.03)

                    ColumnLayout {
                        id: modelInfoCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.smallSpacing }
                        spacing: 2
                        PlasmaComponents.Label {
                            text: modelData.name || ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize; font.weight: Font.DemiBold
                        }
                        PlasmaComponents.Label {
                            text: i18n("In: %1  Out: %2", Api.formatTokens(modelData.input_limit || 0), Api.formatTokens(modelData.output_limit || 0))
                            font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05; opacity: 0.4
                        }
                    }
                }
            }
        }

        // Footer
        PlasmaComponents.Label {
            visible: appRoot.geminiOk
            text: { var d = new Date(); return i18n("Updated %1", d.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)) }
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05; opacity: 0.25
            Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; Layout.margins: Kirigami.Units.smallSpacing
        }
        Item { Layout.fillHeight: true }
    }
}
