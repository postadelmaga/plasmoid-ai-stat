import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api
import "../charts"
import "../components"

Flickable {
    id: summaryTab

    required property var appRoot

    contentWidth: width
    contentHeight: summaryCol.implicitHeight + Kirigami.Units.largeSpacing
    clip: true
    flickableDirection: Flickable.VerticalFlick
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: scrollBar; policy: QQC2.ScrollBar.AsNeeded }

    // Aggregate helpers
    readonly property double totalTokToday: {
        var t = 0
        if (appRoot.enableClaude) t += appRoot.tokInToday + appRoot.tokOutToday
        if (appRoot.enableGeminiCli) t += appRoot.gcliTokInToday + appRoot.gcliTokOutToday
        if (appRoot.enableAntigravity) t += appRoot.agTokInToday + appRoot.agTokOutToday
        if (appRoot.enableOpenCode) t += appRoot.ocTokInToday + appRoot.ocTokOutToday
        return t
    }
    readonly property double totalTokWeek: {
        var t = 0
        if (appRoot.enableClaude) t += appRoot.tokInWeek + appRoot.tokOutWeek
        if (appRoot.enableGeminiCli) t += appRoot.gcliTokInWeek + appRoot.gcliTokOutWeek
        if (appRoot.enableAntigravity) t += appRoot.agTokInWeek + appRoot.agTokOutWeek
        if (appRoot.enableOpenCode) t += appRoot.ocTokInWeek + appRoot.ocTokOutWeek
        return t
    }
    readonly property double totalTokMonth: {
        var t = 0
        if (appRoot.enableClaude) t += appRoot.tokInMonth + appRoot.tokOutMonth
        if (appRoot.enableGeminiCli) t += appRoot.gcliTokInMonth + appRoot.gcliTokOutMonth
        if (appRoot.enableAntigravity) t += appRoot.agTokInMonth + appRoot.agTokOutMonth
        if (appRoot.enableOpenCode) t += appRoot.ocTokInMonth + appRoot.ocTokOutMonth
        return t
    }
    readonly property int totalActiveSessions: {
        var n = 0
        if (appRoot.enableClaude) n += appRoot.activeSessions
        if (appRoot.enableGeminiCli) n += appRoot.gcliActiveSessions
        if (appRoot.enableOpenCode) n += appRoot.ocActiveSessions
        return n
    }
    readonly property real combinedRate: Math.max(appRoot.instantAllRate, appRoot.gcliInstantAllRate, appRoot.ocInstantAllRate, appRoot.agInstantAllRate)
    readonly property real combinedOutputRate: Math.max(appRoot.instantOutputRate, appRoot.gcliInstantOutputRate, appRoot.ocInstantOutputRate, appRoot.agInstantOutputRate)
    readonly property real combinedAvg: Math.max(appRoot.rateAll30m, appRoot.gcliRateAll30m, appRoot.ocRateAll30m, appRoot.agRateAll30m)

    ColumnLayout {
        id: summaryCol
        width: parent.width - Kirigami.Units.smallSpacing - (scrollBar.visible ? scrollBar.width : 0)
        spacing: Kirigami.Units.mediumSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: i18n("All Providers")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
                Layout.fillWidth: true
            }
            Item { Layout.fillWidth: true }

            RowLayout {
                visible: summaryTab.totalActiveSessions > 0
                spacing: Kirigami.Units.smallSpacing / 2
                Rectangle { width: 7; height: 7; radius: 3.5; color: Kirigami.Theme.positiveTextColor }
                PlasmaComponents.Label {
                    text: summaryTab.totalActiveSessions + " active"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.positiveTextColor; opacity: 0.7
                }
            }

            QQC2.ToolButton { icon.name: "view-refresh"; onClicked: appRoot.refreshAll() }
        }

        // Aggregate Token Stats
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Total Tokens") }
            GridLayout {
                Layout.fillWidth: true
                columns: 3; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard { label: i18n("Today"); value: Api.formatTokens(summaryTab.totalTokToday); accent: Kirigami.Theme.highlightColor; Layout.fillWidth: true }
                StatCard { label: i18n("Week"); value: Api.formatTokens(summaryTab.totalTokWeek); accent: Kirigami.Theme.positiveTextColor; Layout.fillWidth: true }
                StatCard { label: i18n("Month"); value: Api.formatTokens(summaryTab.totalTokMonth); accent: Kirigami.Theme.neutralTextColor; Layout.fillWidth: true }
            }
        }

        // Combined Tachometer
        Item {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            property real _tachoW: appRoot.onDesktop ? Kirigami.Units.gridUnit * 10 : Kirigami.Units.gridUnit * 8
            implicitHeight: _tachoW * 0.72

            Tachometer {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent._tachoW
                height: parent._tachoW * 0.72
                value: summaryTab.combinedRate
                avgValue: summaryTab.combinedAvg
                maxValue: 300000000
                label: i18n("tok/h")
                innerValue: summaryTab.combinedOutputRate
                innerMaxValue: 500000
            }
        }

        // Per-provider breakdown
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Providers") }

            // Claude
            ProviderRow {
                visible: appRoot.enableClaude
                Layout.fillWidth: true
                providerName: "Claude"
                iconName: "preferences-system-performance"
                tokToday: appRoot.tokInToday + appRoot.tokOutToday
                tokWeek: appRoot.tokInWeek + appRoot.tokOutWeek
                activeSessions: appRoot.activeSessions
                accentColor: Kirigami.Theme.highlightColor
                totalToday: summaryTab.totalTokToday
            }

            // Gemini CLI
            ProviderRow {
                visible: appRoot.enableGeminiCli
                Layout.fillWidth: true
                providerName: "Gemini CLI"
                iconName: "akonadiconsole"
                tokToday: appRoot.gcliTokInToday + appRoot.gcliTokOutToday
                tokWeek: appRoot.gcliTokInWeek + appRoot.gcliTokOutWeek
                activeSessions: appRoot.gcliActiveSessions
                accentColor: Kirigami.Theme.positiveTextColor
                totalToday: summaryTab.totalTokToday
            }

            // Antigravity
            ProviderRow {
                visible: appRoot.enableAntigravity
                Layout.fillWidth: true
                providerName: "Antigravity"
                iconName: "code-context"
                tokToday: appRoot.agTokInToday + appRoot.agTokOutToday
                tokWeek: appRoot.agTokInWeek + appRoot.agTokOutWeek
                activeSessions: 0
                accentColor: Kirigami.Theme.neutralTextColor
                totalToday: summaryTab.totalTokToday
            }

            // OpenCode
            ProviderRow {
                visible: appRoot.enableOpenCode
                Layout.fillWidth: true
                providerName: "OpenCode"
                iconName: "utilities-terminal"
                tokToday: appRoot.ocTokInToday + appRoot.ocTokOutToday
                tokWeek: appRoot.ocTokInWeek + appRoot.ocTokOutWeek
                activeSessions: appRoot.ocActiveSessions
                accentColor: Kirigami.Theme.linkColor
                totalToday: summaryTab.totalTokToday
            }
        }

        // Combined 12h Chart (merge fine tokens from all providers)
        Item {
            visible: _mergedFine.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing

            property var _mergedFine: {
                var all = []
                if (appRoot.enableClaude) all = all.concat(appRoot.fineTokens)
                if (appRoot.enableGeminiCli) all = all.concat(appRoot.gcliFineTokens)
                if (appRoot.enableAntigravity) all = all.concat(appRoot.agFineTokens)
                if (appRoot.enableOpenCode) all = all.concat(appRoot.ocFineTokens)
                return all
            }

            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("12h") }
                HourlyChart { Layout.fillWidth: true; Layout.fillHeight: true; rawData: parent.parent._mergedFine; bucketMinutes: 5 }
            }
        }

        // Combined Daily Chart
        Item {
            visible: _mergedDaily.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing

            property var _mergedDaily: {
                var all = []
                if (appRoot.enableClaude) all = all.concat(appRoot.dailyTokens)
                if (appRoot.enableGeminiCli) all = all.concat(appRoot.gcliDailyTokens)
                if (appRoot.enableAntigravity) all = all.concat(appRoot.agDailyTokens)
                if (appRoot.enableOpenCode) all = all.concat(appRoot.ocDailyTokens)
                return all
            }

            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("Daily History") }
                DailyChart { Layout.fillWidth: true; Layout.fillHeight: true; chartData: parent.parent._mergedDaily }
            }
        }

        // Footer
        PlasmaComponents.Label {
            text: { var d = new Date(); return i18n("Updated %1", d.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)) }
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05; opacity: 0.25
            Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; Layout.margins: Kirigami.Units.smallSpacing
        }
        Item { Layout.fillHeight: true }
    }

    // ── ProviderRow: inline component for per-provider summary ──
    component ProviderRow: Rectangle {
        id: provRow
        property string providerName: ""
        property string iconName: ""
        property double tokToday: 0
        property double tokWeek: 0
        property int activeSessions: 0
        property color accentColor: Kirigami.Theme.highlightColor
        property double totalToday: 1

        implicitHeight: provRowLayout.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: Kirigami.Units.cornerRadius
        color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.06)
        border.width: 1
        border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.12)

        // Usage proportion bar
        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            radius: parent.radius
            width: parent.width * Math.min(1.0, totalToday > 0 ? tokToday / totalToday : 0)
            color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.06)
            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }

        RowLayout {
            id: provRowLayout
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.smallSpacing }
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: provRow.iconName
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                opacity: 0.7
            }

            PlasmaComponents.Label {
                text: provRow.providerName
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            // Active dot
            Rectangle {
                visible: provRow.activeSessions > 0
                width: 6; height: 6; radius: 3
                color: Kirigami.Theme.positiveTextColor
            }

            PlasmaComponents.Label {
                text: Api.formatTokens(provRow.tokToday)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                color: provRow.accentColor
            }

            PlasmaComponents.Label {
                text: "/" + Api.formatTokens(provRow.tokWeek) + "w"
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                opacity: 0.4
            }
        }
    }
}
