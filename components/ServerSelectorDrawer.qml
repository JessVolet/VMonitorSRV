import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property var serversList: pluginData.serversList || []
    property int activeServerIndex: pluginData.activeServerIndex || 0

    signal serverSelected(int index)
    signal openHostsFile()
    signal reloadHostsFile()

    // Renderizado para barra horizontal
    horizontalBarPill: Component {
        StyledRect {
            implicitWidth: contentLayout.implicitWidth + Theme.spacingM * 2
            implicitHeight: root.barThickness
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHighest

            RowLayout {
                id: contentLayout
                anchors.fill: parent
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingS

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
        }
    }

    // Popout (Menú desplegable) con la lista de servidores
    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "Monitored Servers"
            detailsText: "Select a server to monitor"

            ColumnLayout {
                width: parent.width
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
                            onClicked: {
                                root.activeServerIndex = index
                                root.serverSelected(index)
                            }
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 320
    popoutHeight: 300
}