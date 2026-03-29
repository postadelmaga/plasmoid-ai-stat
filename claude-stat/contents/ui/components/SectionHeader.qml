import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

RowLayout {
    property alias text: label.text

    Layout.fillWidth: true
    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents.Label {
        id: label
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        font.weight: Font.DemiBold
        opacity: 0.5
    }

    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Qt.rgba(Kirigami.Theme.textColor.r,
                       Kirigami.Theme.textColor.g,
                       Kirigami.Theme.textColor.b, 0.1)
        Layout.alignment: Qt.AlignVCenter
    }
}
