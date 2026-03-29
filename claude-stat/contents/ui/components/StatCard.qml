import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Rectangle {
    id: card

    property string label: ""
    property string value: "0"
    property string sub: ""
    property color accent: Kirigami.Theme.highlightColor
    property bool pulse: false

    implicitHeight: Kirigami.Units.gridUnit * 3
    radius: Kirigami.Units.cornerRadius
    color: Qt.rgba(accent.r, accent.g, accent.b, card.pulse ? 0.05 + 0.06 * _pulseGlow : 0.06)
    border.width: 1
    border.color: Qt.rgba(accent.r, accent.g, accent.b, card.pulse ? 0.18 + 0.18 * _pulseGlow : 0.15)

    property real _pulseGlow: 0

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0

        // Top label
        PlasmaComponents.Label {
            text: card.label
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.0
            opacity: 0.45
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: 1
        }

        // Value with glow (Rectangle is much cheaper than Canvas)
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: valueLabel.implicitWidth + 16
            implicitHeight: valueLabel.implicitHeight + 8

            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 1.2; height: parent.height * 1.2
                radius: width / 2
                visible: card.value !== "0"
                color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.12)
                opacity: 0.6
            }

            PlasmaComponents.Label {
                id: valueLabel
                anchors.centerIn: parent
                text: card.value
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.6
                font.weight: Font.Bold
                color: card.accent
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Sub label
        PlasmaComponents.Label {
            text: card.sub
            font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.95
            opacity: 0.35
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
            visible: text.length > 0
        }
    }
}
