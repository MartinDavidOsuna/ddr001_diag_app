# Rendimiento, recursos y accesibilidad — Etapa 4B

Objetivos no certificados: arranque usable <3 s en gama media, filtros <300 ms, foto <8 s y galería usable con 1000 miniaturas.

La galería aísla JSON corrupto, usa miniaturas, conserva filtros y pagina en lotes de 100. Los formularios liberan TextEditingController; ubicación y GPRS cancelan streams/timers; no deben crearse escaneos de cajas dentro de cada tile.

Checklist manual: objetivos 48×48, contraste, Semantics/Tooltips, estado además de color, teclado numérico, foco/error legible, texto 1×–2×, pantalla pequeña, rotación y TalkBack. Estas condiciones requieren certificación física; compilar no las acredita.
