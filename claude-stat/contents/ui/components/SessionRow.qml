import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/anthropic.js" as Api

Rectangle {
    id: sessionRow

    property var sessionData: ({})

    implicitHeight: sessionCol.implicitHeight + Kirigami.Units.smallSpacing * 2
    radius: Kirigami.Units.cornerRadius
    color: Qt.rgba(Kirigami.Theme.textColor.r,
                   Kirigami.Theme.textColor.g,
                   Kirigami.Theme.textColor.b, 0.03)

    ColumnLayout {
        id: sessionCol
        anchors {
            left: parent.left; right: parent.right
            top: parent.top
            margins: Kirigami.Units.smallSpacing
        }
        spacing: 2

        RowLayout {
            Layout.fillWidth: true

            PlasmaComponents.Label {
                text: Api.shortModel(sessionData.model || "")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                visible: (sessionData.duration_min || 0) > 0
                text: Api.formatDuration(sessionData.duration_min || 0)
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.0
                opacity: 0.4
            }

            PlasmaComponents.Label {
                text: Api.formatCost(sessionData.cost || 0)
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.weight: Font.DemiBold
                color: Kirigami.Theme.neutralTextColor
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents.Label {
                text: Api.formatTokens(sessionData.tokens || 0) + " tokens"
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                opacity: 0.4
            }

            PlasmaComponents.Label {
                visible: (sessionData.lines_added || 0) > 0 || (sessionData.lines_removed || 0) > 0
                text: "+" + (sessionData.lines_added || 0) + " -" + (sessionData.lines_removed || 0)
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                opacity: 0.4
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.Label {
                text: {
                    var ts = sessionData.timestamp || ""
                    if (!ts) return ""
                    try {
                        var d = new Date(ts)
                        var now = new Date()
                        var diff = now - d
                        if (diff < 3600000) return Math.round(diff / 60000) + "m ago"
                        if (diff < 86400000) return Math.round(diff / 3600000) + "h ago"
                        return Math.round(diff / 86400000) + "d ago"
                    } catch(e) { return "" }
                }
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
                opacity: 0.3
            }
        }
    }
}
