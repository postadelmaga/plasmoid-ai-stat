import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    property string value: ""
    property string label: ""

    spacing: 0
    Layout.fillWidth: true

    PlasmaComponents.Label {
        text: value
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter
    }
    PlasmaComponents.Label {
        text: label
        font.pointSize: Kirigami.Theme.smallFont.pointSize * 0.92
        opacity: 0.4
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter
    }
}
