1. Visión General del ProyectoDesarrollar un Composite Plugin nativo para DankMaterialShell (DMS ≥ 1.5.0) llamado fedsrv-control. El plugin consumirá en tiempo real la API REST local creada en Python/Bottle ([http://10.190.217.209:61208/api/widget](http://10.190.217.209:61208/api/widget)) para monitorear recursos, almacenamiento Btrfs, redes e infraestructura de contenedores Podman en un servidor Fedora Linux.2. Arquitectura del Componente (type: "composite")El plugin proporcionará dos superficies interactivas principales:DankBar Widget (widget): Indicador compacto en la barra superior con pill horizontal/vertical y un Popout flotante enriquecido (PopoutComponent).Desktop Widget (desktop): Dashboard flotante directamente en el escritorio usando DesktopPluginComponent de Quickshell.3. Estructura de Archivos del ProyectoPlaintext~/.config/DankMaterialShell/plugins/fedsrv-control/
├── plugin.json                 # Manifiesto del Plugin
├── FedSrvWidget.qml            # Componente DankBar + Popout
├── FedSrvDesktop.qml           # Componente Desktop Layer Widget
├── FedSrvSettings.qml          # Panel de configuración de parámetros
├── StartupCheck.qml            # Verificación previa de conexión/dependencias
├── README.md                   # Documentación de instalación
└── assets/
    └── icon.svg                # Icono personalizado del widget
4. Definición del Manifiesto (plugin.json)JSON{
  "id": "fedsrv-control",
  "name": "Fedora Server Control",
  "description": "Monitoreo en vivo de CPU, RAM, Btrfs, Redes y Contenedores Podman vía API Bottle",
  "version": "1.0.0",
  "author": "JessVolet",
  "icon": "server",
  "type": "composite",
  "capabilities": ["dankbar-widget", "desktop-widget"],
  "components": {
    "widget": "./FedSrvWidget.qml",
    "desktop": "./FedSrvDesktop.qml"
  },
  "settings": "./FedSrvSettings.qml",
  "startupCheck": "./StartupCheck.qml",
  "requires_dms": ">=1.5.0",
  "permissions": ["network", "settings_read", "settings_write"]
}
5. Especificaciones de Endpoints y Polling RatesPara garantizar un rendimiento de 60 FPS en QML sin saturar el UI Thread, la recolección HTTP mediante XMLHttpRequest se dividirá en dos frecuencias de refresco:A. Peticiones de Alta Frecuencia (Cada 2.0 segundos)GET /api/widget/resources: Retorna CPU %, RAM %, Disco Raíz % y alerts_count.GET /api/widget/containers/count: Conteo dinámico de contenedores (total, activos, caídos, problemas).GET /api/widget/containers/cpu/{id}: (Sólo bajo demanda cuando el Popout está visible y se inspecciona un contenedor activo).GET /api/widget/network/{id}: (Sólo bajo demanda cuando se expande el detalle de tráfico de una interfaz de red).B. Peticiones de Baja Frecuencia / Bajo Demanda (Cada 15.0 - 30.0 segundos)GET /api/widget/information: Hostname, CPU Model, OS Name, Uptime.GET /api/widget/storage/subvolumes: Lista y ocupación de subvolúmenes Btrfs.GET /api/widget/network: Lista de la interfaz física (eth0).GET /api/widget/network/virtual: Lista de interfaces virtuales (podman0, veth*, br-test, etc.).GET /api/widget/containers: Lista global de contenedores Podman con estado, imagen, uptime y string de memoria.6. Diseño Visual e Interfaz de Usuario (UI/UX)6.1 DankBar Pill (horizontalBarPill / verticalBarPill)Estado Normal: Muestra el icono server, la temperatura de la CPU (°C) y la memoria RAM en porcentaje (ej: 58°C | 53.3%).Indicador de Estado: Dot dinámico:Verde (Theme.primary): Funcionamiento normal (0 alertas, contenedores sin problemas).Rojo/Ámbar (Theme.error / #f59e0b): Existen alertas del sistema (alerts_count > 0) o contenedores en estado error/unhealthy.6.2 Popout Flotante (popoutContent)Anchura base: 420px, Altura base: 580px.Header: Hostname (fedsrv-t), CPU Model (i7-13620H), Kernel y Uptime con botón de refresco forzado.Sección Recursos: Tres barras de progreso estilizadas (StyledRect) con colores del Theme para CPU, RAM y Almacenamiento Raíz.Sección Subvolúmenes Btrfs: Vista contraíble/desplegable con el listado de subvolúmenes, porcentaje de uso y punto de montaje.Sección Redes: Tarjeta principal para la interfaz física (eth0) con IPs y estado UP, más un selector/desplegable con barra de búsqueda para filtrar las interfaces virtuales (podman0, veth*).Sección Contenedores Podman: Módulo interactivo con tarjetas por contenedor.Badges de estado (RUNNING en verde, STOPPED en gris, ERROR en rojo).Botones rápidos por contenedor: Reiniciar, Detener y Copiar ID.7. Componentes QML — Implementación del Código Base7.1 FedSrvSettings.qmlQMLimport QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root
    pluginId: "fedsrv-control"

    StyledText {
        width: parent.width
        text: "Configuración de Fedora Control"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "apiBaseUrl"
        label: "URL Base de la API"
        description: "Dirección IP y puerto del backend Bottle"
        placeholder: "http://10.190.217.209:61208/api/widget"
        defaultValue: "http://10.190.217.209:61208/api/widget"
    }

    SliderSetting {
        settingKey: "refreshInterval"
        label: "Intervalo de Refresco (segundos)"
        description: "Frecuencia de actualización de CPU/RAM"
        defaultValue: 2
        minimum: 1
        maximum: 10
        unit: "s"
    }
}
7.2 StartupCheck.qmlQMLimport QtQuick
import qs.Common

QtObject {
    function check(done) {
        // Verifica conectividad básica con la API de Python antes de habilitar el plugin
        Proc.runCommand("fedsrv.check", ["curl", "-s", "-m", "2", "http://10.190.217.209:61208/api/widget/information"], function(stdout, exitCode) {
            if (exitCode === 0 && stdout.trim().length > 0) {
                done(null)
            } else {
                done({
                    title: "Servidor Inaccesible",
                    details: "No se pudo conectar a http://10.190.217.209:61208.\nAsegúrate de que main.py esté corriendo en la VM/Servidor."
                })
            }
        })
    }
}
7.3 FedSrvWidget.qml (Bar Widget & Popout principal)QMLimport QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    layerNamespacePlugin: "fedsrv-control"

    property string baseUrl: pluginData.apiBaseUrl || "http://10.190.217.209:61208/api/widget"
    property int intervalSecs: pluginData.refreshInterval || 2

    // Propiedades Reactivas
    property var sysInfo: ({})
    property var sysResources: ({ cpu: { usage_percent: 0, temp_c: 0 }, memory: { usage_percent: 0 }, disk_root: { usage_percent: 0 }, alerts_count: 0 })
    property var containerStats: ({ total: 0, running: 0, stopped: 0, problems: 0 })
    property var containerList: []
    property var subvolumesList: []
    property var virtualNets: []
    property bool isOffline: false

    // Timer de Polling Rápido (2s)
    Timer {
        interval: root.intervalSecs * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fetchFastMetrics()
        }
    }

    // Timer de Polling Lento (20s)
    Timer {
        interval: 20000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fetchSlowMetrics()
        }
    }

    function fetchFastMetrics() {
        httpGet(baseUrl + "/resources", function(data) {
            if (data) root.sysResources = data
        })
        httpGet(baseUrl + "/containers/count", function(data) {
            if (data) root.containerStats = data
        })
    }

    function fetchSlowMetrics() {
        httpGet(baseUrl + "/information", function(data) {
            if (data) root.sysInfo = data
        })
        httpGet(baseUrl + "/containers", function(data) {
            if (data && data.containers) root.containerList = data.containers
        })
        httpGet(baseUrl + "/storage/subvolumes", function(data) {
            if (data && data.subvolumes) root.subvolumesList = data.subvolumes
        })
        httpGet(baseUrl + "/network/virtual", function(data) {
            if (data && data.interfaces) root.virtualNets = data.interfaces
        })
    }

    function httpGet(url, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.timeout = 2500
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    root.isOffline = false
                    try {
                        callback(JSON.parse(xhr.responseText))
                    } catch (e) {
                        callback(null)
                    }
                } else {
                    root.isOffline = true
                    callback(null)
                }
            }
        }
        xhr.send()
    }

    // --- VISUALIZACIÓN EN LA BARRA (HORIZONTAL) ---
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS

            DankIcon {
                name: "server"
                size: root.iconSize
                color: root.isOffline ? Theme.error : (root.containerStats.problems > 0 ? "#f59e0b" : Theme.primary)
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.isOffline ? "OFFLINE" : `${root.sysResources.cpu.usage_percent}% | ${root.sysResources.memory.usage_percent}%`
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    // --- VISUALIZACIÓN EN LA BARRA (VERTICAL) ---
    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: "server"
                size: root.iconSize
                color: root.isOffline ? Theme.error : Theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: `${Math.round(root.sysResources.cpu.usage_percent)}%`
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // --- POPOUT FLOTANTE COMPLETO ---
    popoutWidth: 420
    popoutHeight: 580

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: root.sysInfo.hostname || "Fedora Server"
            detailsText: `${root.sysInfo.cpu_name || "CPU"} • ${root.sysInfo.os_name || "Linux"}`
            showCloseButton: true

            ColumnLayout {
                width: parent.width
                spacing: Theme.spacingM

                // Tarjeta de Recursos
                StyledRect {
                    Layout.fillWidth: true
                    height: 110
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText { text: "CPU Usage"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                            Item { Layout.fillWidth: true }
                            StyledText { text: `${root.sysResources.cpu.usage_percent}% (${root.sysResources.cpu.temp_c || 0}°C)`; font.pixelSize: Theme.fontSizeSmall; color: Theme.primary; font.weight: Font.Bold }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText { text: "RAM Usage"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                            Item { Layout.fillWidth: true }
                            StyledText { text: `${root.sysResources.memory.usage_percent}%`; font.pixelSize: Theme.fontSizeSmall; color: "#a6e3a1"; font.weight: Font.Bold }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText { text: "Disk Root (/)"; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceText }
                            Item { Layout.fillWidth: true }
                            StyledText { text: `${root.sysResources.disk_root.usage_percent}%`; font.pixelSize: Theme.fontSizeSmall; color: "#89ptb4"; font.weight: Font.Bold }
                        }
                    }
                }

                // Lista de Contenedores Podman
                StyledText {
                    text: `Contenedores Podman (${root.containerStats.running} Activos / ${root.containerStats.problems} Errores)`
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Bold
                    color: Theme.surfaceText
                }

                ListView {
                    Layout.fillWidth: true
                    implicitHeight: 180
                    clip: true
                    model: root.containerList
                    spacing: Theme.spacingS

                    delegate: StyledRect {
                        width: parent.width
                        height: 50
                        radius: Theme.cornerRadius
                        color: modelData.status === "running" ? Theme.surfaceContainerHighest : "#311b1b"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingS

                            DankIcon {
                                name: modelData.status === "running" ? "play_circle" : "error"
                                color: modelData.status === "running" ? "#a6e3a1" : "#f38ba8"
                            }

                            ColumnLayout {
                                spacing: 2
                                StyledText { text: modelData.name; font.pixelSize: Theme.fontSizeMedium; color: Theme.surfaceText; font.weight: Font.Bold }
                                StyledText { text: `${modelData.image} • ${modelData.memory_usage}`; font.pixelSize: Theme.fontSizeSmall; color: Theme.surfaceVariantText }
                            }

                            Item { Layout.fillWidth: true }

                            StyledText {
                                text: modelData.status.toUpperCase()
                                font.pixelSize: Theme.fontSizeSmall
                                color: modelData.status === "running" ? "#a6e3a1" : "#f38ba8"
                                font.weight: Font.Bold
                            }
                        }
                    }
                }
            }
        }
    }
}
8. Ciclo de Pruebas y Despliegue en VivoA. Symlink para DesarrolloBashln -sf ~/.config/DankMaterialShell/plugins/fedsrv-control \
       ~/repos/DankMaterialShell/quickshell/dms-plugins/fedsrv-control
B. Recarga en Caliente (Hot-Reloading)Sin reiniciar el entorno completo de escritorio, recarga el estado del plugin con IPC:Bashdms ipc call plugins reload fedsrv-control
C. Inspección de ErroresSi ocurre algún fallo en las llamadas HTTP o el renderizado en QML:Bashdms ipc call plugins status fedsrv-control
9. Criterios de AceptaciónConsumo Eficiente: Uso de CPU $< 1\%$ en el proceso quickshell mientras el widget se encuentra activo.Tolerancia a Fallos: Si la VM o el script main.py en Python se apaga, el widget debe mostrar el estado OFFLINE sin congelar ni congelar la barra DankBar.Mantenimiento: Cero lógica pesada en QML; el cliente se limita únicamente a consumir estructuras JSON procesadas previamente por la API de Bottle en Python.
