import QtQuick
import QtQuick.Layouts

Rectangle {
    id: row
    required property var theme
    required property var ev
    signal clicked()
    height: 44
    radius: 15
    color: ma.containsMouse ? theme.alpha(theme.accent, 0.12) : theme.alpha(theme.fg, 0.065)
    border.width: 1
    border.color: theme.alpha(theme.accent, 0.065)
    Behavior on color { ColorAnimation { duration: 120 } }

    readonly property string secondary: ev.video && ev.conference ? ev.calendar + " · " + ev.conference
                                      : ev.location !== "" ? ev.location : ev.calendar

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6; anchors.rightMargin: 10; anchors.topMargin: 4; anchors.bottomMargin: 4
        spacing: 7
        Rectangle { Layout.fillHeight: true; width: 4; radius: 2; color: row.ev.color }
        Column {
            Layout.preferredWidth: 34
            Text { text: row.ev.allDay ? "All day" : row.ev.start; color: row.theme.muted; font.family: row.theme.font; font.pixelSize: 9 }
            Text { visible: !row.ev.allDay; text: row.ev.end; color: row.theme.muted; font.family: row.theme.font; font.pixelSize: 9 }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                Layout.fillWidth: true
                text: row.ev.title; elide: Text.ElideRight
                color: row.theme.fg; font.family: row.theme.font; font.pixelSize: 11; font.weight: Font.Medium
            }
            Text {
                Layout.fillWidth: true
                text: row.secondary; elide: Text.ElideRight
                color: row.theme.muted; font.family: row.theme.font; font.pixelSize: 10
            }
        }
        Row {
            spacing: 3
            visible: row.ev.video || row.ev.location !== "" || row.ev.attendees > 0
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: row.ev.video ? "videocam" : row.ev.location !== "" ? "location_on" : "group"
                size: 17; fill: 1; color: row.theme.accent
            }
            Text {
                visible: !row.ev.video && row.ev.location === "" && row.ev.attendees > 0
                anchors.verticalCenter: parent.verticalCenter
                text: row.ev.attendees; color: row.theme.accent; font.family: row.theme.font; font.pixelSize: 10
            }
        }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.clicked() }
}
