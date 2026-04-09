import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api
import "../charts"
import "../components"

Flickable {
    id: ocTab
    required property var appRoot

    function openInFileManager(path) {
        if (!path || path.length === 0) return
        Qt.openUrlExternally("file://" + encodeURI(path))
    }

    contentWidth: width
    contentHeight: ocCol.implicitHeight + Kirigami.Units.largeSpacing
    clip: true
    flickableDirection: Flickable.VerticalFlick
    QQC2.ScrollBar.vertical: QQC2.ScrollBar { id: scrollBar; policy: QQC2.ScrollBar.AsNeeded }

    ColumnLayout {
        id: ocCol
        width: parent.width - Kirigami.Units.smallSpacing - (scrollBar.visible ? scrollBar.width : 0)
        spacing: Kirigami.Units.mediumSpacing

        // Section 1: Header
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                text: "OpenCode"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.5
                Layout.fillWidth: true
            }
            Item { Layout.fillWidth: true }

            RowLayout {
                visible: appRoot.ocActiveSessions > 0
                spacing: Kirigami.Units.smallSpacing / 2
                Rectangle { width: 7; height: 7; radius: 3.5; color: Kirigami.Theme.positiveTextColor }
                PlasmaComponents.Label {
                    text: appRoot.ocActiveSessions + " active"
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    color: Kirigami.Theme.positiveTextColor; opacity: 0.7
                }
            }

            QQC2.BusyIndicator {
                running: appRoot.ocLoading; visible: appRoot.ocLoading
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.ToolButton { icon.name: "view-refresh"; onClicked: appRoot.refreshAll() }
        }

        // Section 2: Token Stats (StatCards grid)
        ColumnLayout {
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Token Stats") }
            GridLayout {
                Layout.fillWidth: true
                columns: 3; columnSpacing: Kirigami.Units.smallSpacing; rowSpacing: Kirigami.Units.smallSpacing
                StatCard {
                    label: i18n("Today")
                    value: Api.formatTokens(appRoot.ocTokInToday + appRoot.ocTokOutToday)
                    accent: Kirigami.Theme.highlightColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Week")
                    value: Api.formatTokens(appRoot.ocTokInWeek + appRoot.ocTokOutWeek)
                    accent: Kirigami.Theme.positiveTextColor
                    Layout.fillWidth: true
                }
                StatCard {
                    label: i18n("Month")
                    value: Api.formatTokens(appRoot.ocTokInMonth + appRoot.ocTokOutMonth)
                    accent: Kirigami.Theme.neutralTextColor
                    Layout.fillWidth: true
                }
            }
        }

        // Section 3: Dashboard — Tachometer ONLY (centered, no quota rings)
        Item {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            property real _tachoW: appRoot.onDesktop ? Kirigami.Units.gridUnit * 10 : Kirigami.Units.gridUnit * 8
            implicitHeight: _tachoW * 0.72

            Tachometer {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent._tachoW
                height: parent._tachoW * 0.72
                value: appRoot.ocInstantAllRate
                avgValue: appRoot.ocRateAll30m
                maxValue: 300000000
                label: i18n("tok/h")
                innerValue: appRoot.ocInstantOutputRate
                innerMaxValue: 500000
            }
        }

        // Section 4: 12h Token History Chart
        Item {
            visible: appRoot.ocFineTokens.length > 0; Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("12h") }
                HourlyChart { Layout.fillWidth: true; Layout.fillHeight: true; rawData: appRoot.ocFineTokens; bucketMinutes: 5 }
            }
        }

        // Section 5: Daily History Chart
        Item {
            visible: appRoot.ocDailyTokens.length > 0; Layout.fillWidth: true
            Layout.preferredHeight: appRoot.onDesktop ? Kirigami.Units.gridUnit * 8 : Kirigami.Units.gridUnit * 6
            Layout.margins: Kirigami.Units.smallSpacing
            ColumnLayout {
                anchors.fill: parent; spacing: Kirigami.Units.smallSpacing
                SectionHeader { text: i18n("Daily History") }
                DailyChart { Layout.fillWidth: true; Layout.fillHeight: true; chartData: appRoot.ocDailyTokens }
            }
        }

        // Section 6: Models
        ColumnLayout {
            property var _modelKeys: Object.keys(appRoot.ocModelsUsed).sort(function(a, b) {
                var ta = (appRoot.ocModelsUsed[a].input || 0) + (appRoot.ocModelsUsed[a].output || 0)
                var tb = (appRoot.ocModelsUsed[b].input || 0) + (appRoot.ocModelsUsed[b].output || 0)
                return tb - ta
            })
            property double _maxTok: {
                var max = 0
                for (var i = 0; i < _modelKeys.length; i++) {
                    var t = (appRoot.ocModelsUsed[_modelKeys[i]].input || 0) + (appRoot.ocModelsUsed[_modelKeys[i]].output || 0)
                    if (t > max) max = t
                }
                return max || 1
            }
            visible: _modelKeys.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Models") }
            Repeater {
                model: parent._modelKeys
                ColumnLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: 1
                    ModelRow {
                        Layout.fillWidth: true
                        modelName: modelData
                        inputTokens: appRoot.ocModelsUsed[modelData].input || 0
                        outputTokens: appRoot.ocModelsUsed[modelData].output || 0
                        cost: 0
                        maxTokens: parent.parent._maxTok
                    }
                    PlasmaComponents.Label {
                        text: appRoot.ocModelsUsed[modelData].provider || ""
                        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.85
                        opacity: 0.35
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                    }
                }
            }
        }

        // Section 7: Recent Sessions
        ColumnLayout {
            visible: appRoot.ocRecentSessions.length > 0
            Layout.fillWidth: true; Layout.margins: Kirigami.Units.smallSpacing; spacing: Kirigami.Units.smallSpacing
            SectionHeader { text: i18n("Recent Sessions") }
            Repeater {
                model: appRoot.ocRecentSessions
                Rectangle {
                    required property var modelData
                    readonly property string rowPath: {
                        var p = modelData.path || modelData.cwd || modelData.project || modelData.title || ""
                        return (typeof p === "string" && p.length > 0 && p.charAt(0) === "/") ? p : ""
                    }
                    Layout.fillWidth: true
                    implicitHeight: sessCol.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.03)
                    border.width: ocRecentMouse.containsMouse ? 1 : 0
                    border.color: Kirigami.Theme.highlightColor

                    ColumnLayout {
                        id: sessCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.smallSpacing }
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label {
                                text: modelData.title || modelData.id || ""
                                font.pointSize: Kirigami.Theme.smallFont.pointSize; font.weight: Font.DemiBold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                            PlasmaComponents.Label {
                                text: Api.formatDuration(modelData.duration_min || 0)
                                font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.4
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            PlasmaComponents.Label {
                                text: Api.formatTokens(modelData.tokens || 0) + " tok"
                                font.pointSize: Kirigami.Theme.smallFont.pointSize; color: Kirigami.Theme.highlightColor
                            }
                            PlasmaComponents.Label {
                                text: (modelData.model || "") + (modelData.provider ? " \u00b7 " + modelData.provider : "")
                                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95; opacity: 0.35
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }

                    MouseArea {
                        id: ocRecentMouse
                        anchors.fill: parent
                        enabled: parent.rowPath.length > 0
                        hoverEnabled: enabled
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: ocTab.openInFileManager(parent.rowPath)
                    }
                }
            }
        }

        // Section 8: Footer
        PlasmaComponents.Label {
            text: { var d = new Date(); return i18n("Updated %1", d.toLocaleTimeString(Qt.locale(), Locale.ShortFormat)) }
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05; opacity: 0.25
            Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; Layout.margins: Kirigami.Units.smallSpacing
        }
        Item { Layout.fillHeight: true }
    }
}
