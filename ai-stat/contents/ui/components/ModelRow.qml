import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api

ColumnLayout {
    id: modelRow

    property string modelName: ""
    property double inputTokens: 0
    property double outputTokens: 0
    property double cost: 0
    property double maxTokens: 1

    spacing: 2

    RowLayout {
        Layout.fillWidth: true

        PlasmaComponents.Label {
            text: Api.shortModel(modelRow.modelName)
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }

        PlasmaComponents.Label {
            text: Api.formatTokens(inputTokens + outputTokens)
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.5
        }

        PlasmaComponents.Label {
            visible: cost > 0
            text: Api.formatCost(cost)
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.weight: Font.DemiBold
            color: Kirigami.Theme.neutralTextColor
        }
    }

    Rectangle {
        id: barTrack
        Layout.fillWidth: true
        height: 6
        radius: 3
        clip: true
        color: Qt.rgba(Kirigami.Theme.textColor.r,
                       Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b, 0.06)

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Rectangle {
                id: inputBar
                width: {
                    if (modelRow.maxTokens <= 0) return 0
                    var w = (modelRow.inputTokens / modelRow.maxTokens) * barTrack.width
                    return Math.max(0, Math.min(barTrack.width, w))
                }
                height: parent.height
                radius: 3
                color: Kirigami.Theme.highlightColor

                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }

            Rectangle {
                width: {
                    if (modelRow.maxTokens <= 0) return 0
                    var remaining = Math.max(0, barTrack.width - inputBar.width)
                    var w = (modelRow.outputTokens / modelRow.maxTokens) * barTrack.width
                    return Math.max(0, Math.min(remaining, w))
                }
                height: parent.height
                radius: 3
                color: Kirigami.Theme.positiveTextColor

                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
            }
        }
    }
}
