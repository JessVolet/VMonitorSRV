# fedsrv-control

**Fedora Server Control** es un *Composite Plugin* nativo para DankMaterialShell (DMS ≥ 1.5.0) diseñado para monitorear en tiempo real los recursos y servicios de un servidor Fedora Linux.

## Vista Previa de Características

Este plugin se divide en varias superficies interactivas para proporcionar toda la información del servidor sin saturar el entorno de escritorio:

*   **Widget en DankBar:** Un indicador discreto que se sitúa en la barra superior del sistema (soporta vista horizontal y vertical). Muestra rápidamente el uso de CPU y RAM, junto con un ícono que cambia de color para alertar sobre problemas en el servidor.
*   **Panel Flotante Detallado (Popout):** Al hacer clic en el widget, se despliega un panel rico en información que muestra:
    *   **Información del Host:** Nombre del equipo, modelo de CPU, sistema operativo y tiempo de actividad.
    *   **Recursos del Sistema:** Barras de uso estilizadas para CPU, RAM y almacenamiento Btrfs de la raíz.
    *   **Contenedores Podman:** Una lista interactiva de los contenedores en ejecución o detenidos, mostrando su estado en vivo, imagen utilizada y consumo de memoria.
*   **Widget de Escritorio (Desktop):** Un panel que se puede anclar directamente en el fondo de escritorio para monitoreo continuo.

## Rendimiento y Estabilidad

Construido pensando en el rendimiento, `fedsrv-control` mantiene el uso de la CPU por debajo del 1%. Utiliza un sistema inteligente de polling asíncrono para consumir una API REST (basada en Python/Bottle) que hace todo el trabajo pesado en el servidor. 
Además, es completamente tolerante a fallos: si el servidor se desconecta, el plugin pasa de forma segura a un estado "OFFLINE" sin afectar o congelar la interfaz de usuario de DMS.

## Requisitos e Instalación

1.  DankMaterialShell versión 1.5.0 o superior.
2.  Un servidor Fedora corriendo el backend de Python/Bottle (expuesto en `http://10.190.217.209:61208` por defecto).
3.  Instalación ubicando la carpeta del plugin en `~/.config/DankMaterialShell/plugins/fedsrv-control`.
4.  Cargar el plugin utilizando `dms ipc call plugins reload fedsrv-control`.

Se incluye también una pestaña de configuración integrada (`FedSrvSettings.qml`) para cambiar la URL de la API y los tiempos de refresco directamente desde la UI de DMS.
