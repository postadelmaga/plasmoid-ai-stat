import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../charts"
import "../components"

Flickable {
    id: kiroTab

    required property var appRoot

    contentWidth: width
    contentHeight: kiroCol.implicitHeight + Kirigami.Units.largeSpacing
    clip: true
    flickableDirection: Flickable.VerticalFlick
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: scrollBar; policy: QQC2.ScrollBar.AsNeeded }

    ColumnLayout {
        id: kiroCol
        width: parent.width - Kirigami.Units.smallSpacing - (scrollBar.visible ? scrollBar.width : 0)
        spacing: Kirigami.Units.mediumSpacing

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: "Kiro" + (appRoot.kiroVersion ? " v" + appRoot.kiroVersion : "")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
                Layout.fillWidth: true
            }
            Item { Layout.fillWidth: true }

            RowLayout {
                visible: appRoot.kiroRunning
                spacing: Kirigami.Units.smallSpacing / 2
                Rectangle {
                    width: 7; height: 7; radius: 3.5
                    color: Kirigami.Theme.positiveTextColor
                }
                PlasmaComponents.Label {
                    text: i18n("running")
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.positiveTextColor
                    opacity: 0.7
                }
            }

            PlasmaComponents.Label {
                text: appRoot.kiroLastFetchedMs > 0
                      ? i18n("Fetched %1", new Date(appRoot.kiroLastFetchedMs).toLocaleTimeString(Qt.locale(), Locale.ShortFormat))
                      : i18n("Fetched --")
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.92
                opacity: 0.45
            }

            QQC2.BusyIndicator {
                running: appRoot.kiroLoading; visible: appRoot.kiroLoading
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.ToolButton { icon.name: "view-refresh"; onClicked: appRoot.refreshAll() }
        }

        // Credits meter
        Item {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: appRoot.kiroCreditsLimit > 0
            implicitHeight: kiroMeterCol.implicitHeight

            Column {
                id: kiroMeterCol
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                DualQuotaRing {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Kirigami.Units.gridUnit * 5.8
                    height: Kirigami.Units.gridUnit * 5.8
                    outerUsed: appRoot.kiroCreditsUsed
                    outerLimit: appRoot.kiroCreditsLimit
                    outerLabel: "used"
                    outerColor: outerPct > 0.9 ? Kirigami.Theme.negativeTextColor :
                                outerPct > 0.7 ? Kirigami.Theme.neutralTextColor :
                                Kirigami.Theme.highlightColor
                    innerUsed: Math.max(0, appRoot.kiroCreditsLimit - appRoot.kiroCreditsUsed)
                    innerLimit: appRoot.kiroCreditsLimit
                    innerLabel: "left"
                    innerColor: Kirigami.Theme.positiveTextColor
                }

                PlasmaComponents.Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: i18n("Credits %1% (%2 / %3)",
                               Math.round((Math.max(0, appRoot.kiroCreditsUsed) / Math.max(1, appRoot.kiroCreditsLimit)) * 100),
                               appRoot.kiroCreditsUsed,
                               appRoot.kiroCreditsLimit)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.9
                    opacity: 0.45
                }
            }
        }

        // Stats
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Installation") }
            GridLayout {
                Layout.fillWidth: true
                columns: 2; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard {
                    label: i18n("Powers Installed")
                    value: appRoot.kiroPowersInstalled.toString() + " / ∞"
                    accent: Kirigami.Theme.highlightColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Extensions")
                    value: appRoot.kiroExtensions.toString() + " active"
                    accent: Kirigami.Theme.positiveTextColor
                    Layout.fillWidth: true
                }
            }
        }
        
        // Usage Info
        ColumnLayout {
            visible: appRoot.kiroVersion
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("System") }
            
            Rectangle {
                Layout.fillWidth: true
                height: versionInfo.implicitHeight + Kirigami.Units.smallSpacing * 2
                color: Kirigami.Theme.alternateBackgroundColor
                radius: 4
                
                ColumnLayout {
                    id: versionInfo
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing / 2
                    
                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: i18n("Version")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.6
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                        }
                        PlasmaComponents.Label {
                            text: appRoot.kiroVersion
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.weight: Font.Bold
                            Layout.fillWidth: true
                        }
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: i18n("Status")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.6
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                        }
                        PlasmaComponents.Label {
                            text: appRoot.kiroRunning ? i18n("Running") : i18n("Stopped")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: appRoot.kiroRunning ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
                            Layout.fillWidth: true
                        }
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: i18n("Credits")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.6
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                        }
                        PlasmaComponents.Label {
                            text: appRoot.kiroCreditsUsed + " / " + appRoot.kiroCreditsLimit
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: {
                                var pct = appRoot.kiroCreditsLimit > 0 ? (appRoot.kiroCreditsUsed / appRoot.kiroCreditsLimit) : 0
                                return pct > 0.9 ? Kirigami.Theme.negativeTextColor : 
                                       pct > 0.7 ? Kirigami.Theme.neutralTextColor : 
                                       Kirigami.Theme.highlightColor
                            }
                            font.weight: Font.Bold
                            Layout.fillWidth: true
                        }
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: i18n("Home")
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.6
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                        }
                        PlasmaComponents.Label {
                            text: "~/.kiro"
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.family: "monospace"
                            opacity: 0.5
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        // Powers List
        ColumnLayout {
            visible: appRoot.kiroPowers.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing

            SectionHeader { text: i18n("Installed Powers (%1)", appRoot.kiroPowers.length) }

            Repeater {
                model: appRoot.kiroPowers
                Rectangle {
                    Layout.fillWidth: true
                    height: powerRow.implicitHeight + Kirigami.Units.smallSpacing
                    color: Kirigami.Theme.alternateBackgroundColor
                    radius: 4

                    RowLayout {
                        id: powerRow
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing
                        
                        Rectangle {
                            width: 3
                            height: parent.height - 4
                            color: Kirigami.Theme.highlightColor
                            radius: 1.5
                        }

                        PlasmaComponents.Label {
                            text: modelData.name
                            font.weight: Font.Bold
                            Layout.fillWidth: true
                        }

                        PlasmaComponents.Label {
                            text: "v" + modelData.version
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            opacity: 0.5
                        }
                    }
                }
            }
        }
        
        // Empty state
        ColumnLayout {
            visible: appRoot.kiroPowers.length === 0 && !appRoot.kiroLoading
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.largeSpacing * 2
            spacing: Kirigami.Units.smallSpacing
            
            PlasmaComponents.Label {
                text: "⚡"
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 3
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                opacity: 0.3
            }
            
            PlasmaComponents.Label {
                text: i18n("No powers installed")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                opacity: 0.5
            }
            
            PlasmaComponents.Label {
                text: i18n("Install powers with: kiro power install <name>")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.family: "monospace"
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                opacity: 0.3
            }
        }

        Item { Layout.fillHeight: true }
    }
}
