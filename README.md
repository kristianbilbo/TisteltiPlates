# TisteltiPlates

Addon para WoW Forever (interfaz 16001). Esta rama integra la base remota **0.8.10.2**, los cambios de colores, controles y solo nombres, y la configuración funcional completa. El candidato **0.8.11-dev.3** es local y aún no está publicado.

Abre **Opciones → AddOns → TisteltiPlates**. Allí están las pestañas General, Apariencia, Comportamiento, PvP y Avanzado, con desplazamiento vertical. La entrada **TisteltiPlates → Alitas y mazmorras** ofrece acceso directo a los ámbitos, los estilos y sus alitas. No requiere escribir comandos.

Los comandos de acceso siguen disponibles como atajos opcionales.

## Configuración

| Sección | Qué controla |
| --- | --- |
| General | Activación general; mundo abierto, mazmorras, bandas, campos de batalla y arenas; diagnóstico de placas/controles de WoW; alitas de solo nombres por estilo. |
| Apariencia | Estilos independientes de grupo, banda y hermandad; borde, alas, nivel, nombre y distintivo de hermandad, mérito; prioridad grupo/hermandad. Acentos de aliados/enemigos: nombre y marco nativos, por clase, facción, personalizados o heredados. |
| Comportamiento | Compactación de grupo/banda, qué oculta; reposición de controles por relación; separación de auras; ocultación del ala derecha; prioridad de auras PvP. |
| PvP | Activación; aliados/enemigos; emblema, alas, icono de clase; alas de hermandad de ambas facciones; objetivo seleccionado y recomendado por separado; colores de barra y uso de mérito en las alas. |
| Avanzado | Escala y anchura fija, tamaño de adornos, espera/tamaño del compacto, anclajes y desplazamientos de controles, separación de auras, margen de solapamiento, tamaño/separación de alitas, texto de hermandad, reglas de recomendación y tamaños/brillo/paletas PvP. |

En **General** están juntos los ámbitos y el bloque **Alitas en el modo solo nombres de WoW**. Dentro de una mazmorra o banda excluida, la cabecera lo indica y ofrece un botón para activar allí las placas y alitas. El botón cambia solo ese ámbito; los interruptores de estilos y alitas conservan su valor. El acceso **Configurar estilos y ver alitas de ejemplo** abre Apariencia en la escena Solo nombres.

Cada sección permite restaurar sus ajustes con un segundo clic de confirmación. Los campos numéricos se aplican con **Intro**; **Escape** o salir del campo descarta la edición. Se limitan los valores al intervalo indicado. Los controles dependientes se atenúan cuando su interruptor está apagado.

Las preferencias se guardan en `TisteltiPlatesDB`. La actualización conserva los valores existentes y los opt-outs explícitos. Las nuevas opciones reciben valores definidos; no se borran los datos de mérito ni ajustes ajenos a una sección al restaurarla.

## Prioridad y desactivación

1. El interruptor general y los ámbitos condicionan todos los módulos visuales, incluidos colores y controles.
2. El modo nativo **solo nombres** sustituye a la decoración completa. Sus alitas requieren activar tanto el estilo correspondiente como las alitas globales y las de ese estilo.
3. Con PvP activo, su presentación sustituye los estilos clásicos. Desmarcar aliados/enemigos en PvP deja disponibles los acentos generales de Apariencia; para retirarlos, desactiva también esos acentos o elige Nativo.
4. Fuera de PvP, grupo/banda y hermandad se resuelven mediante la prioridad guardada. Los acentos generales de aliados no sustituyen esas decoraciones.
5. Los marcos que no se pueden modificar se respetan. Las restauraciones protegidas, la geometría y los cambios de modo pendientes se aplican al terminar el combate; el panel informa de ello.

**Nativo** conserva o restaura el color que tenía WoW. **Personalizado** aplica el RGB guardado. **Heredado** mantiene el comportamiento anterior: usa el color personalizado si estaba activado; en PvP, sin él, usa el nombre por facción y el marco de reacción/clase. Elegir explícitamente Nativo evita ese color de respaldo. Un solo módulo controla cada nombre/borde y conserva su alfa.

La ampliación al pasar el cursor está retirada: no hay módulo, opción, controlador ni prueba de esa función en el paquete. La escala fija clásica es otra opción, independiente y configurable.

## Valores iniciales y reglas

| Función | Valores iniciales y comportamiento |
| --- | --- |
| Ámbitos | Mundo abierto, campos de batalla y arenas activados; mazmorras y bandas desactivadas. Se aplican igual a clásico, PvP, colores, alitas y controles. |
| Estilos clásicos | Grupo, banda y hermandad activados, con todos sus componentes. Prioridad hermandad. Al migrar, banda hereda el antiguo grupo si aún no tenía ajustes. |
| Acentos | Enemigos: nombre y borde personalizados rojos; aliados: color nativo fuera de PvP. Ambos conservan el modo Heredado al migrar. |
| Compacto | Activado para grupo y banda. Solo aliados que pertenecen al grupo/banda, incluso si usan el estilo de hermandad. Durante combate y 30 segundos desde su final; la espera es ajustable. Oculta nombre/distintivo de hermandad y mérito, conserva las dos alas pequeñas. |
| Controles | Reposición activada para aliados y enemigos. Ancla junto al nivel, con desplazamiento X=8, Y=0; puede anclarse a la salud. Las unidades sin relación de jugador reconocida usan el interruptor general de controles. |
| Auras clásicas | Separación activada sobre las alas; 6 puntos entre filas. Se desactiva de forma independiente de los controles. |
| Auras PvP | Ocultan solo adornos solapados, con margen 4. Una aura visible que no se puede medir reserva espacio. Interruptor independiente de la ocultación del ala por control. |
| Ala derecha | Se oculta con un control visible; el compacto de grupo conserva ambas alas. Nunca reactiva un ala deshabilitada en Apariencia. |
| Solo nombres | Activado para los tres estilos; alitas de 16 puntos y separación 4, junto al texto visible. No fuerza placas ni CVars. |
| Geometría | Escala fija ×1,25 y anchura ×1,22 en clásico; adornos ×1. Se restaura al desactivarla. Con EllesmereUINameplates, la geometría la gestiona ese addon. |
| Texto de hermandad | Tamaño 10, desplazamiento vertical −3. El texto sin decoración también se retira al desactivar Hermandad o su nombre. |
| PvP | Desactivado inicialmente. Aliados/enemigos, emblema, icono de clase, alas y ambos destacados activados dentro del modo. Alas solo de tu hermandad Alianza por defecto; Horda es opcional. |
| Recomendación | Calavera real del grupo o al menos 2 compañeros con el mismo objetivo; estabilidad 2 segundos. Fuentes, votos y tiempo se configuran por separado. Solo enemigos vivos y visibles con datos públicos. |
| Mérito PvP | Bronce 1–4, plata 5–9, oro 10–14; sin dato o con colores de mérito apagados, acabado neutro. Brillo 1, alas ×0,8 e icono de clase 22. |

El destacado de objetivo es blanco; la recomendación es dorada e incluye el motivo. Es solo información visual: no selecciona, marca ni ataca. No cambia vida, lanzamientos, filtros de auras ni temporizadores.

El mérito usa las fuentes disponibles y la caché del addon. Seleccionar jugadores no solicita comparaciones de logros en segundo plano. No se presenta un dato ausente como rango oficial. `/tistelti merito` permite consultar el dato conocido del objetivo o del propio personaje.

## Vistas previas

La muestra usa los mismos pintores y resolución de colores que las placas. Permite elegir grupo, banda, hermandad, aliado o enemigo; facción; mérito ficticio; presentación normal, compacto de grupo, control activo, solo nombres, objetivo o recomendación. Los colores personalizados y la opción Nativo se reflejan también en PvP.

La escena de compacto selecciona grupo/banda y las de objetivo seleccionan enemigo. La hermandad de muestra se supone fuera del grupo salvo que se elija grupo/banda. Las muestras enseñan el aspecto guardado, aunque el ámbito actual esté excluido o el modo esté pendiente de cambiar en combate. No simulan colisiones de auras reales, restricciones del cliente ni la geometría aportada por otra interfaz.

## Instalación y convivencia

Extrae la carpeta `TisteltiPlates` del ZIP dentro de `_forever_/Interface/AddOns/`. Debe quedar `AddOns/TisteltiPlates/TisteltiPlates.toc`, sin carpeta duplicada. Recarga la interfaz tras actualizar. Activa las placas correspondientes en WoW: el addon no las activa por ti.

ForeverCCPosition está integrado y conserva su licencia en `LICENSE-ForeverCCPosition.txt`. Desactiva su copia independiente para evitar que dos addons reposicionen los mismos controles. No necesita TisteltiGuild. EllesmereUI conserva el control de su tamaño de placas y nombres externos.

El arte y los originales están en `Media/`. Las variantes de alas de grupo/banda conservan sus fuentes, TGA y descripción; no se ha reemplazado el arte en esta revisión.

## Comandos

- `/tistelti`, `/tistelti opciones`: General. `/tistelti vista`: Apariencia. `/tistelti pvp`: PvP.
- `/tistelti on` / `off`; `/tistelti pvp on` / `off`.
- `/tistelti grupo`, `banda` o `guild` con `on` / `off`.
- `/tistelti borde grupo/banda/guild plata` (también otros metales, `oroazul`, `oro`, `clase`, `rango`).
- `/tistelti color grupo/banda/guild R G B`, con canales de 0 a 1.
- `/tistelti icono grupo/banda/guild on` / `off`: mérito. El antiguo `animales` equivale a activarlo.
- `/tistelti tamano 0.8–1.8`: escala del adorno; `/tistelti enemigos rojo` / `clase`: barra PvP.
- `/tistelti cc`: diagnóstico de configuración nativa. `/tistelti merito`: consulta; no asigna rango manual.

## Validación

Doce suites de marcos simulados comprueban carga y orden de los nueve módulos, migración, configuración y callbacks reales de UI, ámbitos, restauración de colores/alfa/anclajes, exclusión de instancias, combate, datos restringidos, reciclaje, componentes, compacto, recomendación, auras, solo nombres y Honor.

Desde la raíz, con Python y la biblioteca compartida de Lua 5.4 instalada:

```sh
python tests/run_tests.py
```

También pueden ejecutarse directamente los archivos `tests/test_*.lua` con Lua 5.1; con Lua 5.4 hay que definir `loadstring=load` y `unpack=table.unpack`. El ejecutor no instala ni descarga dependencias.

Las pruebas simuladas no sustituyen la comprobación dentro de WoW Forever. Quedan por validar visualmente el panel a las escalas de interfaz reales, los adornos con nombres largos, los controles en combate y la convivencia con la versión instalada de EllesmereUI.
