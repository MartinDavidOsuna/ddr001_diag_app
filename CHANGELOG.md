# Changelog

Todos los cambios notables de **DIAGNOSTICO HIDRANTES** se documentan aquí.

## Unreleased — Etapa 3

- Etapa 4C liga una prueba HTTPS mínima a un `Network` celular Android y separa capacidades INTERNET/VALIDATED del resultado HTTP.
- La evaluación Wi-Fi permanece manual y ahora aplica ramas condicionales con normalización persistida y validación central.
- Etapa 4B agrega máquina de estados común, inmutabilidad y revisiones para RV/RF.
- Se incorporan journal recuperable, auditor de integridad, cuarentena y recuperación conservadora al arranque.
- RF incorpora colecciones UUID de válvulas, corridas de reductora y alarmas, snapshots de instrumentos y resultado agregado.
- Medios incorporan reconciliación; galería aísla corrupción, conserva filtros y carga miniaturas incrementalmente.
- Nuevo levantamiento RV + RF queda coordinado mediante journal; sincronización local prepara idempotencia y dependencias para una API futura.
- Diagnóstico automático limitado a GPRS/red celular, con contador máximo de 60 segundos y resultados diferenciados.
- Evaluación Wi-Fi manual mediante respuestas explícitas, sin escaneo de redes ni permisos adicionales.
- Etapa 4 inicia estabilización local: respuestas trivalentes RV persistentes, ubicación automática, diagnóstico de red parcial honesto, resolución central de RV finalizado, navegación RF y traducciones visibles.
- Evidencia por sección incorpora contador reutilizable y daños visibles incorpora evaluación individual por componente.
- Inicio recupera el Resumen de jornada compacto de cuatro métricas con reglas compartidas con Hidrantes.
- La alerta de Inicio ahora responde en toda su superficie y abre detalle o ficha según su relación.
- La barra principal se simplifica a Todos, RV, RF, En proceso, Sin sincronizar y Finalizado.
- El chip activo se centra mediante un controlador horizontal y medición real del viewport antes de consumir la solicitud.
- REPORTE FUNCIONAL offline en diez pasos con borrador, suspensión y visita sin prueba.
- Habilitación funcional explícita y Nuevo levantamiento con RV, RF o RV + RF.
- Instrumentos, series versionadas, unidades normalizadas y tolerancias DEMO no oficiales.
- Pruebas hidráulicas, mecánicas, eléctricas, comunicaciones, alarmas y fugas.
- Evidencia funcional sobre el pipeline fotográfico existente.
- Filtros RV/RF y visibilidad automática del chip solicitado desde Inicio.
- Cajas Hive no destructivas, cola tipada y trazabilidad funcional ampliada.

## Unreleased — Etapa 1.1

- Navegación horizontal entre secciones y control jerárquico de Atrás con `PopScope`.
- Sincronización incremental simulada de asignaciones, con upsert y retiros protegidos.
- Etiquetas cortas permanentes en los marcadores del mapa demo.
- Estado global corregido para diagnósticos, fotografías, trazabilidad y errores.
- Simulación controlada de actualización disponible, opcional, obligatoria y error.
- Base para consultar un manifiesto remoto con fallback local.

## [0.2.0+3] - 2026-07-13

- Base arquitectónica móvil y tema centralizado.
- Acceso demo, navegación principal y pantallas generales de Etapa 1.
- Datos simulados para hidrantes RV y RF.
- Trazabilidad y cola de sincronización local mediante Hive CE.
- Mapa visual simulado sin SDK cartográfico.
- Base segura para actualización y evidencias fotográficas.

## [0.1.1+2]

- Proyecto Flutter inicial.
## Unreleased — Etapa 2

- Navegación anidada por ramas y protección del botón Atrás.
- Sincronización compacta y cíclica de asignaciones.
- Borradores versionados de REPORTE VISUAL en ocho pasos.
- Captura GPS contextual y conversión local WGS84 a UTM.
- Flujo local para hidrantes no asignados y encontrados en campo.
- Pipeline fotográfico normalizado, almacenamiento privado, SHA-256 y cola pendiente.
- Galería local por hidrante y trazabilidad ampliada.
