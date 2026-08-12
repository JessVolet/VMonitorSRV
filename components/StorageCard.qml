import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property var sysResources: ({ "disk_root": { "usage_percent": 0, "used_bytes": 0, "total_bytes": 0 } })
    property var subvolumesList: []
    property string selectedSubvolName: ""
    property var selectedSubvolData: ({})
    property var getStorageColorFunc: function(val) { return Theme.primary; }
    property var bytesToGbFunc: function(b) { return "0.0 GB"; }
    property bool emptySectionExpanded: false

    readonly property bool hasSubvolumes: root.subvolumesList && Array.isArray(root.subvolumesList) && root.subvolumesList.length > 0

    signal subvolSelected(string name, var data)

    Layout.fillWidth: true
    implicitHeight: stgCol.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    ColumnLayout {
        id: stgCol
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            DankIcon { name: "pie_chart"; color: Theme.primary }
            StyledText {
                text: "Storage"
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM

            DankIcon { name: "pie_chart"; color: root.getStorageColorFunc(root.sysResources.disk_root.usage_percent || 0) }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                StyledText { text: "Root Disk Storage Pool"; font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: Theme.surfaceText }
                StyledText {
                    text: `Used: ${(root.sysResources.disk_root.usage_percent || 0).toFixed(1)}% (${root.bytesToGbFunc(root.sysResources.disk_root.used_bytes)} / ${root.bytesToGbFunc(root.sysResources.disk_root.total_bytes)})`
                    font.pixelSize: Theme.fontSizeSmall
                    color: root.getStorageColorFunc(root.sysResources.disk_root.usage_percent || 0)
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            visible: root.hasSubvolumes
            Layout.fillWidth: true
            spacing: Theme.spacingS

            StyledText {
                text: `Btrfs Subvolumes Wheel (${root.subvolumesList ? root.subvolumesList.length : 0})`
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            ListView {
                id: subvolCarousel
                Layout.fillWidth: true
                implicitHeight: 75
                orientation: ListView.Horizontal
                clip: true
                model: root.subvolumesList
                spacing: Theme.spacingS

                delegate: StyledRect {
                    width: 145
                    height: 68
                    radius: Theme.cornerRadius
                    color: isSelected ? root.getStorageColorFunc(subPercent) : Theme.surfaceContainerHighest

                    property var itemData: typeof modelData === "object" ? modelData : ({ "name": modelData, "percent": 0, "used_bytes": 0 })
                    property string subName: itemData.name || "subvol"
                    property real subPercent: itemData.percent || 0
                    property bool isSelected: root.selectedSubvolName === subName || (root.selectedSubvolName === "" && index === 0)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingS
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            DankIcon {
                                name: "folder"
                                color: isSelected ? Theme.onPrimary : root.getStorageColorFunc(subPercent)
                            }
                            StyledText {
                                text: subName
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: isSelected ? Theme.onPrimary : Theme.surfaceText
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        StyledText {
                            text: `${subPercent.toFixed(1)}% (${root.bytesToGbFunc(itemData.used_bytes || 0)})`
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: isSelected ? Theme.onPrimary : root.getStorageColorFunc(subPercent)
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.subvolSelected(subName, itemData)
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 85
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHighest

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: Theme.spacingXS

                    RowLayout {
                        Layout.fillWidth: true
                        DankIcon { name: "info"; color: root.getStorageColorFunc(root.selectedSubvolData.percent || 0) }
                        StyledText {
                            text: `Selected Subvolume: ${root.selectedSubvolData.name || root.selectedSubvolName || "root"}`
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }
                        Item { Layout.fillWidth: true }
                        StyledText {
                            text: `${(root.selectedSubvolData.percent || 0).toFixed(1)}%`
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: root.getStorageColorFunc(root.selectedSubvolData.percent || 0)
                        }
                    }

                    StyledText {
                        text: `Mount Point: ${root.selectedSubvolData.mount || "/"}`
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: `Used Capacity: ${root.bytesToGbFunc(root.selectedSubvolData.used_bytes)}`
                        font.pixelSize: Theme.fontSizeSmall
                        color: root.getStorageColorFunc(root.selectedSubvolData.percent || 0)
                        font.weight: Font.Bold
                    }
                }
            }
        }

        ColumnLayout {
            visible: !root.hasSubvolumes
            Layout.fillWidth: true
            spacing: Theme.spacingS

            RowLayout {
                Layout.fillWidth: true

                DankIcon {
                    name: "folder_open"
                    color: Theme.surfaceVariantText
                }

                StyledText {
                    text: "Btrfs Subvolumes Wheel (0)"
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.surfaceVariantText
                    Layout.fillWidth: true
                }

                DankButton {
                    iconName: root.emptySectionExpanded ? "expand_less" : "expand_more"
                    backgroundColor: Theme.surfaceContainerHighest
                    textColor: Theme.surfaceText
                    onClicked: root.emptySectionExpanded = !root.emptySectionExpanded
                }
            }

            StyledRect {
                visible: root.emptySectionExpanded
                Layout.fillWidth: true
                implicitHeight: emptyMsgCol.implicitHeight + Theme.spacingM * 2
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHighest

                RowLayout {
                    id: emptyMsgCol
                    anchors.fill: parent
                    anchors.margins: Theme.spacingM
                    spacing: Theme.spacingM

                    DankIcon {
                        name: "lightbulb"
                        color: "#f59e0b"
                        size: 24
                    }

                    StyledText {
                        text: "I understand that a best practice for servers is to divide storage into volumes... consider using VGUARD :)"
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
