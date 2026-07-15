# Diagnóstico GPRS y evaluación Wi-Fi — Etapa 4

## Separación de conceptos

El diagnóstico automático observa exclusivamente la interfaz móvil del teléfono mediante `connectivity_plus`. No escanea Wi-Fi, no enumera SSID/RSSI y no mezcla la conectividad del teléfono con la del módem del hidrante. La evaluación Wi-Fi es manual y se almacena en `WifiTechnicalAssessment`.

## Resultado GPRS

- `available`: Android informó una interfaz móvil activa antes del límite.
- `noCellularNetworksAvailable`: durante 60 segundos no apareció una interfaz móvil observable.
- `indeterminate`: la API o plataforma impidió completar el diagnóstico.
- `cancelled`: el técnico canceló o la pantalla/app interrumpió el proceso.

El controlador persiste inicio y resultado terminal, evita ejecuciones simultáneas y cancela sus timers al finalizar o destruirse. Un análisis interrumpido no se reanuda desde memoria ni se convierte en ausencia de red.

## Alcance de datos

La integración actual no expone operador, registro, tecnología, RSSI celular ni una ruta de internet forzada exclusivamente sobre datos móviles. Estos datos se presentan como “No se pudo determinar”; no se inventan. El resultado describe el teléfono, no certifica el módem GPRS del hidrante.

## Calidad y efectividad DEMO

La calidad `cellular-quality-demo-v1` solo se calcula con dBm real: −70 dBm o mejor equivale a 10; −120 dBm o peor equivale a 1; entre ambos se interpola linealmente. Sin dBm se muestra “No calculable”.

La efectividad usa únicamente indicadores celulares conocidos: interfaz (25 puntos), registro (20), calidad (25), internet celular (20) e intentos exitosos (10). Requiere al menos tres indicadores comprobados y se normaliza a 0–100. La metodología es DEMO y no constituye aprobación técnica oficial.

## Wi-Fi manual

El técnico responde si hay Wi-Fi cercano y si conexión, señal e internet son posibles, usando valores explícitos Sí, No, No verificado y No aplica cuando corresponde. `null` significa solamente “sin responder”. Las observaciones son opcionales. Wi-Fi nunca altera GPRS y GPRS nunca completa Wi-Fi automáticamente.
