import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api

RowLayout {
    id: tokenBar

    property string label: ""
    property double value: 0
    property double maxValue: 1
    property color barColor: Kirigami.Theme.highlightColor

    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents.Label {
        text: tokenBar.label
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        Layout.preferredWidth: Kirigami.Units.gridUnit * 3
        opacity: 0.6
    }

    Rectangle {
        Layout.fillWidth: true
        height: 8
        radius: 4
        color: Qt.rgba(Kirigami.Theme.textColor.r,
                       Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b, 0.06)

        Rectangle {
            width: tokenBar.maxValue > 0
                   ? parent.width * Math.min(1.0, tokenBar.value / tokenBar.maxValue)
                   : 0
            height: parent.height
            radius: 4
            color: tokenBar.barColor

            Behavior on width {
                NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
            }
        }
    }

    PlasmaComponents.Label {
        text: Api.formatTokens(tokenBar.value)
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        font.weight: Font.DemiBold
        Layout.preferredWidth: Kirigami.Units.gridUnit * 3
        horizontalAlignment: Text.AlignRight
    }
}
