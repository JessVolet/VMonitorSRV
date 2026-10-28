import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.DCommon.Widgets

StyledRect {
    id: root
    required property var settingsRoot
    property var servers: []
    property var aliases: ({})
    property var reportedNames: ({})
    property string lastServerKey: ""
    property string validationMessage: ""

    function normalizedOrigin(value) {
        var candidate = String(value || "").trim().replace(/\/+$/, "");
        var match = /^(https?):\/\/([a-zA-Z0-9.-]+|\[[0-9a-fA-F:]+\])(?::([0-9]{1,5}))?$/.exec(candidate);
        if (!match) return "";
        var port = match[3] ? Number(match[3]) : 61208;
        if (port < 1 || port > 65535) return "";
        return match[1] + "://" + match[2] + ":" + port;
    }

    function loadValue() {
        var stored = settingsRoot.loadValue("serverUrls", "");
        servers = String(stored || "").split(",").map(function(value) { return value.trim(); }).filter(function(value) { return value.length > 0; });
        try {
            var parsed = JSON.parse(String(settingsRoot.loadValue("serverAliases", "{}") || "{}"));
            aliases = parsed && typeof parsed === "object" && !Array.isArray(parsed) ? parsed : {};
        } catch (e) { aliases = ({}); }
        var key = servers.join(",");
        if (key !== lastServerKey) {
            lastServerKey = key;
            reportedNames = ({});
            discoverNames();
        }
    }

    function discoverNames() {
        var generation = lastServerKey;
        for (var i = 0; i < servers.length; i++) {
            var origin = normalizedOrigin(servers[i]);
            if (!origin) continue;
            (function(address) {
                var xhr = new XMLHttpRequest();
                xhr.open("GET", address + "/api/widget/information", true);
                xhr.timeout = 3000;
                xhr.onreadystatechange = function() {
                    if (xhr.readyState !== XMLHttpRequest.DONE || generation !== root.lastServerKey || xhr.status < 200 || xhr.status >= 300) return;
                    try {
                        var name = String(JSON.parse(xhr.responseText).hostname || "").trim();
                        if (!name || name === "Unknown") return;
                        var next = Object.assign({}, root.reportedNames);
                        next[address] = name;
                        root.reportedNames = next;
                    } catch (e) {}
                };
                xhr.send();
            })(origin);
        }
    }

    function saveAlias(origin, value) {
        var name = String(value || "").trim();
        if ((aliases[origin] || "") === name) return;
        var next = Object.assign({}, aliases);
        if (name) next[origin] = name;
        else delete next[origin];
        aliases = next;
        settingsRoot.saveValue("serverAliases", JSON.stringify(next));
    }

    function saveServers(next) {
        servers = next;
        settingsRoot.saveValue("serverUrls", next.join(", "));
    }

    function addServer() {
        var origin = normalizedOrigin(addressInput.text);
        if (!origin) {
            validationMessage = "Enter an HTTP(S) host; port 61208 is used by default.";
            return;
        }
        if (servers.indexOf(origin) !== -1) {
            validationMessage = "This server is already in the list.";
            return;
        }
        var next = servers.slice();
        next.push(origin);
        saveServers(next);
        addressInput.text = "";
        validationMessage = "";
    }

    function updateServer(index, value) {
        var origin = normalizedOrigin(value);
        if (!origin) {
            validationMessage = "Enter a valid HTTP(S) address. Port 61208 is used by default.";
            return;
        }
        if (servers.indexOf(origin) !== -1 && normalizedOrigin(servers[index]) !== origin) {
            validationMessage = "This server is already in the list.";
            return;
        }
        var oldOrigin = normalizedOrigin(servers[index]);
        if (oldOrigin === origin) { validationMessage = ""; return; }
        var next = servers.slice();
        next[index] = origin;
        saveServers(next);
        if (aliases[oldOrigin]) {
            var nextAliases = Object.assign({}, aliases);
            nextAliases[origin] = nextAliases[oldOrigin];
            delete nextAliases[oldOrigin];
            aliases = nextAliases;
            settingsRoot.saveValue("serverAliases", JSON.stringify(nextAliases));
        }
        validationMessage = "";
    }

    function removeServer(index) {
        var next = servers.slice();
        var removed = normalizedOrigin(next[index]);
        next.splice(index, 1);
        saveServers(next);
        if (removed && aliases[removed]) saveAlias(removed, "");
    }

    function moveServer(index, delta) {
        var target = index + delta;
        if (target < 0 || target >= servers.length) return;
        var next = servers.slice();
        var item = next[index];
        next[index] = next[target];
        next[target] = item;
        saveServers(next);
    }

    width: parent ? parent.width : 0
    height: implicitHeight
    implicitHeight: cardContent.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.surfaceContainerHigh

    ColumnLayout {
        id: cardContent
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingS

        RowLayout {
            Layout.fillWidth: true
            DIcon { name: "dns"; size: 22; color: Theme.primary }
            StyledText { text: "Servers"; font.pixelSize: Theme.fontSizeLarge; font.weight: Font.Bold; color: Theme.surfaceText; Layout.fillWidth: true }
            StyledText { text: String(root.servers.length); font.pixelSize: Theme.fontSizeMedium; font.weight: Font.Bold; color: Theme.primary }
        }
        StyledText {
            text: "Add each API address. Names are read from /information; you can override them below. The first server powers the desktop widget."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        StyledText {
            visible: root.servers.length === 0
            text: "No servers yet. Add one below to start monitoring."
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        Repeater {
            model: root.servers
            delegate: StyledRect {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 104
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerHighest
                readonly property string origin: root.normalizedOrigin(modelData)
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingS
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        DIcon { name: origin ? "dns" : "error"; size: 16; color: origin ? Theme.primary : Theme.error }
                        DTextField {
                            Layout.fillWidth: true
                            placeholderText: "http://server.local:61208"
                            Component.onCompleted: text = modelData
                            onEditingFinished: root.updateServer(index, text)
                            onAccepted: root.updateServer(index, text)
                        }
                        StyledText { visible: index === 0; text: "DESKTOP"; font.pixelSize: Theme.fontSizeSmall - 1; font.weight: Font.Bold; color: Theme.primary }
                        DButton { iconName: "arrow_upward"; tooltipText: "Move up"; enabled: index > 0; minimumWidth: 0; backgroundColor: Theme.surfaceContainerHigh; textColor: Theme.surfaceText; onClicked: root.moveServer(index, -1) }
                        DButton { iconName: "arrow_downward"; tooltipText: "Move down"; enabled: index < root.servers.length - 1; minimumWidth: 0; backgroundColor: Theme.surfaceContainerHigh; textColor: Theme.surfaceText; onClicked: root.moveServer(index, 1) }
                        DButton { iconName: "delete"; tooltipText: "Remove server"; minimumWidth: 0; backgroundColor: Theme.surfaceContainerHigh; textColor: Theme.error; onClicked: root.removeServer(index) }
                    }
                    DTextField {
                        Layout.fillWidth: true
                        placeholderText: root.reportedNames[origin] || "Name shown in the plugin (optional)"
                        Component.onCompleted: text = root.aliases[origin] || ""
                        onEditingFinished: root.saveAlias(origin, text)
                        onAccepted: root.saveAlias(origin, text)
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            DTextField { id: addressInput; Layout.fillWidth: true; placeholderText: "http://server.local:61208"; onAccepted: root.addServer() }
            DButton { text: "Add"; iconName: "add"; backgroundColor: Theme.primary; textColor: Theme.onPrimary; onClicked: root.addServer() }
        }
        StyledText { visible: root.validationMessage !== ""; text: root.validationMessage; font.pixelSize: Theme.fontSizeSmall; color: Theme.error; wrapMode: Text.WordWrap; Layout.fillWidth: true }
        StyledText { text: "HTTP is supported for trusted LANs. Use HTTPS when the API is exposed beyond your network."; font.pixelSize: Theme.fontSizeSmall - 1; color: Theme.surfaceVariantText; wrapMode: Text.WordWrap; Layout.fillWidth: true }
    }
}
