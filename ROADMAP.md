# Roadmap: fedsrv-control Plugin

*   **Fase 1: Preparación y Configuración**
    *   [x] Revisar los requerimientos y especificaciones del proyecto.
    *   [x] Crear la estructura base del plugin `fedsrv-control`.
    *   [x] Definir el archivo de manifiesto `plugin.json`.
*   **Fase 2: Conectividad y Verificación**
    *   [x] Implementar `StartupCheck.qml` para verificar la conectividad con la API local (Bottle).
    *   [x] Desarrollar el panel de configuración `FedSrvSettings.qml` para la URL de la API e intervalos.
*   **Fase 3: Desarrollo del Widget Base (DankBar)**
    *   [x] Crear la estructura principal en `FedSrvWidget.qml`.
    *   [x] Implementar lógica de peticiones HTTP con temporizadores (alta y baja frecuencia).
    *   [x] Diseñar la vista en la barra superior (`horizontalBarPill` y `verticalBarPill`).
*   **Fase 4: Desarrollo del Panel Flotante (Popout)**
    *   [x] Diseñar la cabecera con la información del host (CPU Model, OS Name, Uptime).
    *   [x] Implementar la sección de Recursos (barras de progreso para CPU, RAM, Disco).
    *   [x] Desarrollar la lista de Contenedores Podman con indicadores de estado.
    *   [x] Integrar vista de Subvolúmenes Btrfs y estadísticas de Red.
*   **Fase 5: Desarrollo del Desktop Widget**
    *   [x] Diseñar e implementar `FedSrvDesktop.qml` para mostrar las estadísticas directamente en el escritorio.
*   **Fase 6: Pruebas y Optimización**
    *   [x] Probar el rendimiento y verificar que el consumo de CPU sea inferior al 1%.
    *   [x] Validar la tolerancia a fallos (mostrar estado OFFLINE de forma segura).
    *   [x] Pruebas de recarga en caliente vía `dms ipc`.
