# Integridad y recuperación local — Etapa 4B

Hive y filesystem no forman una transacción atómica. `OperationJournalEntry` registra fases prepared, documentsWritten, indexesWritten, filesWritten, queueWritten, committed, needsRecovery, failed y quarantined.

Al arranque `RecoveryCoordinator.runLightweight` audita índices, JSON, series, instrumentos, fotos, colas y journals. Solo ejecuta reparaciones inequívocas: retirar índice huérfano, recrear trabajo de medios y confirmar un journal que ya alcanzó queueWritten. Los demás casos quedan `needsRecovery` o revisión manual.

`QuarantineRepository` copia íntegramente contenido corrupto, caja/key, timestamp, error y SHA-256. Nunca elimina el documento fuente ni almacena credenciales. `IntegrityAuditReport` es serializable y la UI debe mostrar únicamente mensajes accionables.

`MediaReconciliationService` conserva originales, detecta archivo/miniatura/cola faltante, corrige uploadedUnverified incoherente y nunca borra una foto verified local.
