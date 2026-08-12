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

    ToggleSetting {
        settingKey: "enableGraphs"
        label: "Enable Mini Sparkline Graphs"
        description: "Turn off mini-charts to conserve GPU and CPU resources"
        defaultValue: true
    }

    SliderSetting {
        settingKey: "refreshInterval"
        label: "Refresh Interval (seconds)"
        description: "Update frequency for high-rate CPU, RAM and Network metrics"
        defaultValue: 2
        minimum: 1
        maximum: 10
        unit: "s"
    }

    StringSetting {
        settingKey: "serversConfig"
        label: "Servers Configuration (JSON)"
        description: "List of monitored servers [{\"name\":\"Fedora Primary\",\"host\":\"192.168.100.200\",\"port\":\"61208\"}]"
        placeholder: "[{\"name\":\"Fedora Main\",\"host\":\"192.168.100.200\",\"port\":\"61208\"}]"
        defaultValue: "[{\"name\":\"Fedora Main\",\"host\":\"192.168.100.200\",\"port\":\"61208\"}]"
    }

    StringSetting {
        settingKey: "apiBaseUrl"
        label: "Default API Base URL"
        description: "Fallback IP address and port if no server list is configured"
        placeholder: "http://192.168.100.200:61208/api/widget"
        defaultValue: "http://192.168.100.200:61208/api/widget"
    }
}
