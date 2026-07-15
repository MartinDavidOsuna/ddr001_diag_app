# Matriz manual — Etapa 4

Estado inicial de todos los casos: No ejecutado. Evidencia: captura, video, traza y exportación JSON cuando aplique.

| ID | Caso | Precondición y pasos | Resultado esperado | Severidad |
|---|---|---|---|---|
| RV1-01 | Correspondencia | Elegir Sí/No/No se puede confirmar; cerrar/reabrir | Selección persistida y trazada | S1 |
| RV1-02 | Fotos identificación | Cámara/biblioteca, abrir contador, eliminar | Conteo íntegro y actualización inmediata | S1 |
| RV2-01 | GPS autorizado | Entrar al paso 2 | Captura automática, coordenadas/UTM/precisión | S1 |
| RV2-02 | Permisos | Denegar, denegar siempre, apagar GPS | Motivo técnico tipado sin justificación manual | S1 |
| RV2-03 | Calidad | Timeout, pobre y válida; reiniciar durante captura | Mejor lectura y estado recuperable | S1 |
| RV5-01 | Fuga | Nivel vacío/con nivel/fuga sin nivel; cerrar | Vacío no bloquea | S1 |
| RV6-01 | Energía | Sí/No/No verificado; reabrir | Triestado persistido | S1 |
| GPRS-01 | Red inmediata | Datos móviles activos | Finaliza anticipadamente como disponible | S1 |
| GPRS-02 | Red tardía | Interfaz aparece tras varios segundos | Detecta red, detiene contador y guarda tiempo real | S1 |
| GPRS-03 | Sin red 60 s | Modo avión o solo Wi-Fi | Contador 01:00→00:00; guarda “No hay redes celulares disponibles” | S1 |
| GPRS-04 | Progreso | Ejecutar diagnóstico | Barra avanza por etapas completadas, no solo por tiempo | S2 |
| GPRS-05 | Restricción/error | Forzar error de plataforma | Resultado indeterminado; nunca ausencia de red | S1 |
| GPRS-06 | Solo Wi-Fi | Wi-Fi activo, móvil ausente | Wi-Fi no se interpreta como GPRS | S1 |
| GPRS-07 | Internet celular | Con y sin salida comprobable | Solo refleja evidencia celular; de lo contrario indeterminado | S1 |
| GPRS-08 | Calidad | Señal disponible/no disponible | Escala 1–10 o No calculable; sin datos inventados | S1 |
| GPRS-09 | Efectividad | Datos suficientes/insuficientes | Porcentaje DEMO o No calculable | S1 |
| GPRS-10 | Cancelar | Cancelar antes del límite | Estado cancelado; timer detenido | S1 |
| GPRS-11 | Salir/cerrar | Abandonar o cerrar durante análisis | Interrumpido; no timeout falso; sin timer huérfano | S1 |
| GPRS-12 | Repetición | Ejecutar dos diagnósticos consecutivos | Nuevo ID; nunca dos timers simultáneos | S1 |
| WIFI-01 | Wi-Fi cercano | Sí/No/No verificado | Selección persiste y se restaura | S1 |
| WIFI-02 | Conexión Wi-Fi | Sí/No/No verificado/No aplica | Selección explícita; null solo sin respuesta | S1 |
| WIFI-03 | Señal Wi-Fi | Sí/No/No verificado/No aplica | Selección persiste | S1 |
| WIFI-04 | Internet Wi-Fi | Sí/No/No verificado/No aplica | No modifica el resultado GPRS | S1 |
| WIFI-05 | Observaciones | Vacío y texto capturado | Opcional, persiste tras reapertura | S2 |
| WIFI-06 | Privacidad | Entrar al paso 6 | Sin escaneo, SSID/RSSI ni permisos Wi-Fi | S1 |
| RV7-01 | Daños | Sin daños y cada componente/estado | Exclusión, comentario y evidencia individual | S1 |
| RV8-01 | Cierre | Revisar Válvulas/Solenoides y popup | Todo en español | S1 |
| RF-01 | Regreso sin RV | Flecha y Anterior en paso 1 | Regresa a ficha, conserva borrador | S1 |
| RF-02 | RV previo | Sin RV, borrador, finalizado, revisión, TMP, 1104 | Resolver tipado selecciona solo finalizado vigente | S1 |

Aplican además íntegramente los casos M01–M32 de `plans/etapa_4_cierre_funcional_estabilizacion_plan.txt`.

## Matriz integral M01–M32

Estado inicial: No ejecutado. Dispositivo, fecha, ejecutor y observaciones deben completarse durante certificación.

| ID | Módulo | Precondición | Pasos | Resultado esperado | Sev. | Estado | Evidencia | Dispositivo | Fecha | Ejecutor | Observaciones |
|---|---|---|---|---|---|---|---|---|---|---|---|
| M01 | Actualización datos | Instalación 0.2.0+3 con datos | Actualizar/abrir | Conserva sesión, cajas, fotos y borradores | S1 | No ejecutado | Export+capturas | Pendiente | Pendiente | Pendiente | |
| M02 | Sesión | Usuario válido/inválido/offline | Iniciar/cerrar/reabrir | Estado y sesión correctos | S2 | No ejecutado | Video+traza | Pendiente | Pendiente | Pendiente | |
| M03 | Navegación | App iniciada | Bottom, swipe, Atrás, gesto | Solo cierra desde Inicio con confirmación | S1 | No ejecutado | Video | Pendiente | Pendiente | Pendiente | |
| M04 | Inicio/filtros | Dataset conocido | Pulsar 4 métricas/6 filtros | Total=listado, chip visible, vertical intacto | S1 | No ejecutado | Video+conteo | Pendiente | Pendiente | Pendiente | |
| M05 | Alertas | Alertas con/sin hidrante | Abrir alertas | Ficha/detalle/mensaje controlado | S2 | No ejecutado | Capturas | Pendiente | Pendiente | Pendiente | |
| M06 | RV | Hidrante asignado | Completar 8 pasos | 100 %, ficha y cierre inmutable | S1 | No ejecutado | Video+JSON | Pendiente | Pendiente | Pendiente | |
| M07 | RV validación | RV nuevo | Omitir cada obligatorio | Error local y borrador conservado | S1 | No ejecutado | Capturas | Pendiente | Pendiente | Pendiente | |
| M08 | Ubicación | Permisos variables | Denegar/apagar/timeout/capturar | Motivo técnico o posición válida | S1 | No ejecutado | Traza+captura | Pendiente | Pendiente | Pendiente | |
| M09 | Daños | RV paso 7 | Daño sin/con foto y archivo faltante | Bloqueo/evidencia correctos | S1 | No ejecutado | Video | Pendiente | Pendiente | Pendiente | |
| M10 | RF | Condiciones completas | Completar 10 pasos | Resultado agregado y cierre | S1 | No ejecutado | Video+JSON | Pendiente | Pendiente | Pendiente | |
| M11 | RF visita | Condición bloqueante | Guardar visita sin prueba | Motivo, evidencia y reprogramación | S1 | No ejecutado | Captura+traza | Pendiente | Pendiente | Pendiente | |
| M12 | Estados | RF activo | Pausar/suspender/reanudar/cancelar | Solo transiciones válidas y trazadas | S1 | No ejecutado | JSON+traza | Pendiente | Pendiente | Pendiente | |
| M13 | Repetición/revisión | RF finalizado | Repetir y crear revisión supervisor | Original inmutable, relaciones correctas | S1 | No ejecutado | JSON | Pendiente | Pendiente | Pendiente | |
| M14 | Válvulas | RF paso 4 | Agregar 3, editar, duplicar, mover, retirar | UUID estable y pruebas independientes | S1 | No ejecutado | Video+JSON | Pendiente | Pendiente | Pendiente | |
| M15 | Reductora | RF paso 4 | Crear 4, aceptar otra, invalidar | Una aceptada por conditionKey, historial íntegro | S1 | No ejecutado | Video+JSON | Pendiente | Pendiente | Pendiente | |
| M16 | Alarmas | RF paso 8 | Varios tipos/intentos, Otra | UUID, descripción, latencia e historial | S1 | No ejecutado | Video+JSON | Pendiente | Pendiente | Pendiente | |
| M17 | Instrumentos | RF paso 2/serie activa | Alta, texto libre, retirar/no apto | Serie activa bloquea retiro; sin catálogos marca/modelo | S1 | No ejecutado | Video+JSON | Pendiente | Pendiente | Pendiente | |
| M18 | Cálculos | Valores patrón | Ejecutar conversiones/fórmulas | Coinciden; patrón cero No calculable | S1 | No ejecutado | Hoja+JSON | Pendiente | Pendiente | Pendiente | |
| M19 | Series | Serie e instrumento | Aceptar/rechazar/fuera rango | Selección explícita y agregado correcto | S1 | No ejecutado | Video | Pendiente | Pendiente | Pendiente | |
| M20 | Nuevo levantamiento | Asignado/no asignado/TMP | Crear RV, RF y cada origen | Trazabilidad/autorización correctas | S1 | No ejecutado | Video+JSON | Pendiente | Pendiente | Pendiente | |
| M21 | RV+RF | Selección ambos | Forzar cierre entre escrituras/reabrir | committed/needsRecovery, sin éxito parcial | S1 | No ejecutado | Journal+video | Pendiente | Pendiente | Pendiente | |
| M22 | Permisos | Permisos revocables | Denegar cámara/ubicación/biblioteca | Mensaje y continuidad segura | S2 | No ejecutado | Capturas | Pendiente | Pendiente | Pendiente | |
| M23 | Fotos | Cámara/biblioteca | Capturar/orientar/procesar | Original, miniatura, hash, contador | S1 | No ejecutado | Archivos+JSON | Pendiente | Pendiente | Pendiente | |
| M24 | Journal | Captura/finalización activa | Matar proceso por fase | Journal recupera o solicita revisión | S1 | No ejecutado | Journal | Pendiente | Pendiente | Pendiente | |
| M25 | Integridad | Copia controlada | Índice/JSON/archivo/miniatura corruptos | Sin pantalla roja; cuarentena/no borrado | S1 | No ejecutado | Audit+quarantine | Pendiente | Pendiente | Pendiente | |
| M26 | Galería | 1000 miniaturas | Filtrar/visor/volver/cargar más | Sin carga de originales en build; contexto conservado | S2 | No ejecutado | Perfil+video | Pendiente | Pendiente | Pendiente | |
| M27 | Sync local | Elementos/dependencias/unverified | Reintentar/reconciliar | allSynchronized exacto y grafo respetado | S1 | No ejecutado | Cola JSON | Pendiente | Pendiente | Pendiente | |
| M28 | Actualización | 4 escenarios demo | Current/optional/required/error | Activos continúan; nuevos bloqueados en required | S1 | No ejecutado | Video | Pendiente | Pendiente | Pendiente | |
| M29 | Cierre forzado | Cada paso/serie/GPRS | Matar y reabrir | Mismo borrador; interrupción controlada | S1 | No ejecutado | Video+traza | Pendiente | Pendiente | Pendiente | |
| M30 | Layout | Pantalla pequeña | Rotar y texto 2× | Sin overflow ni pérdida | S2 | No ejecutado | Capturas | Pendiente | Pendiente | Pendiente | |
| M31 | Accesibilidad | TalkBack/teclado | Recorrer controles/errores | Semántica, foco y toque operables | S2 | No ejecutado | Video | Pendiente | Pendiente | Pendiente | |
| M32 | Rendimiento | Dataset grande/gama media | Arranque, filtros, fotos, galería | Medir contra objetivos; sin afirmar antes | S2 | No ejecutado | Perfil+mediciones | Pendiente | Pendiente | Pendiente | |

## Casos estructurales adicionales 4B

| ID | Módulo | Precondición | Pasos | Resultado esperado | Sev. | Estado | Evidencia | Dispositivo | Fecha | Ejecutor | Observaciones |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 4B-01 | Estado inválido | Reporte completed | Solicitar inProgress/draft | Rechazado con mensaje y traza | S1 | No ejecutado | JSON+traza | Pendiente | Pendiente | Pendiente | |
| 4B-02 | Revisión | Supervisor demo | Corregir RV/RF finalizado | Documento nuevo; original idéntico | S1 | No ejecutado | Diff JSON | Pendiente | Pendiente | Pendiente | |
| 4B-03 | Snapshot | Instrumento usado | Crear serie y editar inventario | Snapshot histórico no cambia | S1 | No ejecutado | JSON | Pendiente | Pendiente | Pendiente | |
| 4B-04 | Media reconcile | uploadedUnverified inconsistente | Ejecutar reconciliación | Nunca se considera verified | S1 | No ejecutado | Cola+JSON | Pendiente | Pendiente | Pendiente | |

## Casos Etapa 4C — red celular real y Wi-Fi condicional

| ID | Módulo | Precondición | Pasos | Resultado esperado | Sev. | Estado | Evidencia | Dispositivo | Fecha | Ejecutor | Observaciones |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 4C-G01 | Aislamiento | Wi-Fi y datos activos | Ejecutar diagnóstico | HTTP usa Network celular; Wi-Fi no satisface resultado | S1 | No ejecutado | Log nativo+captura | Pendiente | Pendiente | Pendiente | |
| 4C-G02 | Solo celular | Datos activos, Wi-Fi apagado | Ejecutar | Adquiere transporte y prueba HTTP | S1 | No ejecutado | JSON+captura | Pendiente | Pendiente | Pendiente | |
| 4C-G03 | Solo Wi-Fi | Datos/SIM sin servicio | Esperar 60 s | No adquiere celular; “Red celular no disponible” | S1 | No ejecutado | Video+JSON | Pendiente | Pendiente | Pendiente | |
| 4C-G04 | Modo avión | Modo avión | Esperar 60 s | Timeout de red, no error HTTP | S1 | No ejecutado | Video+JSON | Pendiente | Pendiente | Pendiente | |
| 4C-G05 | SIM sin datos | Interfaz celular observable | Ejecutar | Red adquirida; internet no confirmado | S1 | No ejecutado | JSON | Pendiente | Pendiente | Pendiente | |
| 4C-G06 | Endpoint | Endpoint inaccesible | Ejecutar | endpointUnavailable; no ausencia de red | S1 | No ejecutado | JSON+log | Pendiente | Pendiente | Pendiente | |
| 4C-G07 | Capacidades | INTERNET sin VALIDATED | Ejecutar | Campos separados y HTTP independiente | S1 | No ejecutado | JSON | Pendiente | Pendiente | Pendiente | |
| 4C-G08 | Validación | VALIDATED disponible | Ejecutar | VALIDATED=true sin asumir por sí solo HTTP | S1 | No ejecutado | JSON | Pendiente | Pendiente | Pendiente | |
| 4C-G09 | HTTP exitoso | Endpoint responde 204 | Ejecutar | cellularInternetConfirmed y latencia | S1 | No ejecutado | JSON+captura | Pendiente | Pendiente | Pendiente | |
| 4C-G10 | HTTP inesperado | Endpoint responde otro código | Ejecutar | unexpectedHttpResponse; red conservada | S1 | No ejecutado | JSON | Pendiente | Pendiente | Pendiente | |
| 4C-G11 | Timeout HTTP | Red adquirida, respuesta lenta | Ejecutar | timeout; internet no confirmado | S1 | No ejecutado | JSON+log | Pendiente | Pendiente | Pendiente | |
| 4C-G12 | TLS | Certificado inválido | Ejecutar | tlsError tipado | S1 | No ejecutado | JSON+log | Pendiente | Pendiente | Pendiente | |
| 4C-G13 | Cancelación | Solicitud activa | Cancelar/salir | Cancelled; callback/conexión/tarea liberados | S1 | No ejecutado | Log nativo | Pendiente | Pendiente | Pendiente | |
| 4C-G14 | Repetición | Prueba previa terminada | Repetir varias veces | Sin callbacks duplicados ni respuestas tardías | S1 | No ejecutado | Log+video | Pendiente | Pendiente | Pendiente | |
| 4C-G15 | Efectividad | Evidencia suficiente/insuficiente | Ejecutar | Porcentaje DEMO o No calculable con indicadores | S1 | No ejecutado | JSON | Pendiente | Pendiente | Pendiente | |
| 4C-G16 | Compatibilidad | Android 10/moderno/iOS | Ejecutar | Android aísla; iOS informa restricción | S1 | No ejecutado | Capturas | Pendiente | Pendiente | Pendiente | |
| 4C-W01 | Rama Sí | Wi-Fi cercana=Sí | Responder conexión=Sí | Muestra y exige señal/internet | S1 | No ejecutado | Video+JSON | Pendiente | Pendiente | Pendiente | |
| 4C-W02 | Rama No | Cambiar Sí→No | Revisar/persistir | Oculta dependientes; guarda notApplicable | S1 | No ejecutado | JSON+traza | Pendiente | Pendiente | Pendiente | |
| 4C-W03 | Rama desconocida | Cambiar Sí→No verificado | Revisar/persistir | Oculta dependientes; no bloquea | S1 | No ejecutado | JSON+traza | Pendiente | Pendiente | Pendiente | |
| 4C-W04 | Reactivación | Cambiar No→Sí | Revisar | Dependientes quedan sin responder, sin valores antiguos | S1 | No ejecutado | JSON | Pendiente | Pendiente | Pendiente | |
| 4C-W05 | Conexión No | Cercana Sí, conexión No | Continuar | Señal/internet ocultas y notApplicable | S1 | No ejecutado | Video+JSON | Pendiente | Pendiente | Pendiente | |
| 4C-W06 | Conexión desconocida | Conexión No verificado | Continuar | Dependientes ocultas; no bloquean | S1 | No ejecutado | Video | Pendiente | Pendiente | Pendiente | |
| 4C-W07 | Persistencia | Cualquier rama | Cerrar/reabrir | Rama y normalización restauradas | S1 | No ejecutado | Video+JSON | Pendiente | Pendiente | Pendiente | |
| 4C-W08 | Privacidad | Abrir paso 6 | Observar permisos/tráfico | Sin escaneo Wi-Fi ni permisos adicionales | S1 | No ejecutado | Manifest+log | Pendiente | Pendiente | Pendiente | |
