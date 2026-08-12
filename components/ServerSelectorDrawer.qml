import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property var serversList: []
    property int activeServerIndex: 0

    signal serverSelected(int index)
    signal openHostsFile()
    signal reloadHostsFile()

    Layout.fillWidth: true
    implicitHeight: Math.max(120, Math.min(220, root.serversList.length * 44 + 50))
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHighest

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXS

            StyledText {
                text: "Select Monitored Server"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.primary
            }

            Item { Layout.fillWidth: true }

            DankButton {
                iconName: "refresh"
                backgroundColor: Theme.surfaceContainerHigh
                textColor: Theme.surfaceText
                onClicked: root.reloadHostsFile()
            }

            DankButton {
                iconName: "edit"
                backgroundColor: Theme.surfaceContainerHigh
                textColor: Theme.surfaceText
                onClicked: root.openHostsFile()
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.serversList
            spacing: Theme.spacingXS
            delegate: StyledRect {
                width: ListView.view.width
                height: 38
                radius: Theme.cornerRadiusSmall
                color: isSelected ? Theme.primary : Theme.surfaceContainerHigh

                property bool isSelected: index === root.activeServerIndex

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingS

                    DankIcon {
                        name: isSelected ? "dns" : "server"
                        color: isSelected ? Theme.onPrimary : Theme.primary
                    }

                    StyledText {
                        text: `${modelData.name || modelData.host} (${modelData.host}:${modelData.port || "61208"})`
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: isSelected ? Font.Bold : Font.Normal
                        color: isSelected ? Theme.onPrimary : Theme.surfaceText
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.serverSelected(index)
                }
            }
        }
    }
}
