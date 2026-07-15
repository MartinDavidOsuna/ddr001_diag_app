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
