import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

import "../../code/formatters.js" as Api

Rectangle {
    id: card

    property var session: ({})
    property real activity: 0   // 0-1, driven by pid activity/rate
    readonly property string clickablePath: {
        var p = session.cwd || ""
        return (typeof p === "string" && p.length > 0 && p.charAt(0) === "/") ? p : ""
    }
    property real _glowAlpha: 0

    Behavior on _glowAlpha { NumberAnimation { duration: 600; easing.type: Easing.InOutSine } }

    SequentialAnimation {
        id: pulseAnim
        loops: Animation.Infinite
        running: card.activity > 0.05
        NumberAnimation { target: card; property: "_glowAlpha"; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
        NumberAnimation { target: card; property: "_glowAlpha"; to: 0.2; duration: 800; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) card._glowAlpha = 0
    }

    function openSessionPath(path) {
        if (!path || path.length === 0) return
        Qt.openUrlExternally("file://" + encodeURI(path))
    }

    visible: (session.tokens || 0) > 0
    implicitHeight: col.implicitHeight + Kirigami.Units.smallSpacing * 2
    radius: Kirigami.Units.cornerRadius
    color: Qt.rgba(Kirigami.Theme.positiveTextColor.r, Kirigami.Theme.positiveTextColor.g, Kirigami.Theme.positiveTextColor.b, 0.06)
    border.width: activePathMouse.containsMouse ? 2 : 1
    border.color: activePathMouse.containsMouse
                  ? Kirigami.Theme.highlightColor
                  : Qt.rgba(Kirigami.Theme.positiveTextColor.r, Kirigami.Theme.positiveTextColor.g, Kirigami.Theme.positiveTextColor.b, 0.12 + _glowAlpha * 0.5)

    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        radius: parent.radius + 1
        z: -1
        color: "transparent"
        border.width: 2
        border.color: Qt.rgba(Kirigami.Theme.positiveTextColor.r, Kirigami.Theme.positiveTextColor.g, Kirigami.Theme.positiveTextColor.b,
                              card._glowAlpha * 0.4 * card.activity)
    }

    ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Kirigami.Units.smallSpacing }
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                text: card.session.cwd || "session"
                font.pointSize: Kirigami.Theme.smallFont.pointSize; font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                text: Api.formatDuration(card.session.duration_min || 0)
                font.pointSize: Kirigami.Theme.smallFont.pointSize; opacity: 0.4
            }
        }

        RowLayout {
            Layout.fillWidth: true; spacing: Kirigami.Units.largeSpacing
            PlasmaComponents.Label {
                text: Api.formatTokens(card.session.tokens || 0) + " tok"
                font.pointSize: Kirigami.Theme.smallFont.pointSize; font.weight: Font.DemiBold
                color: Kirigami.Theme.positiveTextColor
            }
            PlasmaComponents.Label {
                text: (card.session.messages || 0) + " msg"
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05; opacity: 0.4
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: "in:" + Api.formatTokens((card.session.input || 0) + (card.session.cache_read || 0) + (card.session.cache_create || 0))
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05; opacity: 0.4
            }
            PlasmaComponents.Label {
                text: "out:" + Api.formatTokens(card.session.output || 0)
                font.pointSize: Kirigami.Theme.smallFont.pointSize * 1.05; opacity: 0.4
            }
        }
    }

    MouseArea {
        id: activePathMouse
        anchors.fill: parent
        enabled: card.clickablePath.length > 0
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: card.openSessionPath(card.clickablePath)
    }
}
