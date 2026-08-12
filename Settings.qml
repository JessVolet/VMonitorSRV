import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "vMonitorSRV"

    StyledText {
        width: parent.width
        text: "VMonitorSRV Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "apiBaseUrl"
        label: "API Base URL"
        description: "IP address and port of the Bottle backend API"
        placeholder: "http://10.190.217.209:61208/api/widget"
        defaultValue: "http://10.190.217.209:61208/api/widget"
    }

    SliderSetting {
        settingKey: "refreshInterval"
        label: "Refresh Interval (seconds)"
        description: "Update frequency for high-rate CPU/RAM metrics"
        defaultValue: 2
        minimum: 1
        maximum: 10
        unit: "s"
    }
}
