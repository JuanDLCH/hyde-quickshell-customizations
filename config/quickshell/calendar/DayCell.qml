import QtQuick

Item {
    id: cell
    required property var theme
    property int day: 1
    property bool outside: false
    property bool today: false
    property bool selected: false
    property var colors: []
    signal clicked()

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height, 36)
        height: width
        radius: width * 0.38
        scale: ma.pressed ? 0.9 : 1
        color: cell.today ? cell.theme.accent
             : cell.selected ? cell.theme.alpha(cell.theme.accent, 0.22)
             : ma.containsMouse ? cell.theme.alpha(cell.theme.accent, cell.outside ? 0.055 : 0.17) : "transparent"
        border.width: cell.selected ? 1.5 : 0
        border.color: cell.theme.accent
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutBack } }

        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: cell.day
                font.family: cell.theme.font
                font.pixelSize: 12
                font.weight: cell.today || cell.selected ? Font.DemiBold : Font.Normal
                color: cell.today ? cell.theme.bg : cell.outside ? cell.theme.alpha(cell.theme.fg, 0.38) : cell.theme.fg
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2
                height: 6
                Repeater {
                    model: cell.colors.slice(0, 3)
                    Rectangle {
                        required property string modelData
                        width: 5; height: 5; radius: 2.5
                        color: modelData
                        border.width: 1
                        border.color: cell.theme.alpha(cell.today ? cell.theme.bg : cell.theme.fg, 0.55)
                    }
                }
                Text {
                    visible: cell.colors.length > 3
                    text: "+"
                    font.pixelSize: 8
                    color: cell.today ? cell.theme.bg : cell.theme.fg
                }
            }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cell.clicked()
    }
}
