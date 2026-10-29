import QtQuick

// Rounded column surface used by every tab (same look as the calendar columns).
Rectangle {
    required property var theme
    radius: 18
    color: theme.alpha(theme.card, 0.40)
    border.width: 1
    border.color: theme.alpha(theme.accent, 0.12)
}
