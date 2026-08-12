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
    implicitHeight: mainLayout.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHighest

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        // Encabezado con botones compactos (solo icono)
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXS

            StyledText {
                text: "Select Monitored Server"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.primary
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

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

        // Mensaje cuando no se detecta ningún servidor
        StyledText {
            visible: !root.serversList || root.serversList.length === 0
            text: "No servers found in hosts.json"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.spacingS
            Layout.bottomMargin: Theme.spacingS
        }

        // Lista de Servidores
        ColumnLayout {
            visible: root.serversList && root.serversList.length > 0
            Layout.fillWidth: true
            spacing: Theme.spacingXS

            Repeater {
                model: root.serversList

                delegate: StyledRect {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: Theme.cornerRadiusSmall

                    property bool isSelected: index === root.activeServerIndex
                    color: isSelected ? Theme.primary : Theme.surfaceContainerHigh

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
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.serverSelected(index)
                    }
                }
            }
        }
    }
}