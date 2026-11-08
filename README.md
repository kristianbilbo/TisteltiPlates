# TisteltiPlates

Addon para WoW Forever (interfaz 16001). Versión actual: **0.8.9**.

## Auras prioritarias y nombres por facción 0.8.9

En modo PvP los nombres son azules para la Alianza y rojos para la Horda, independientemente del color de clase o barra. Se mantienen fuente, tamaño, posición y alfa del texto y se restaura su color previo al retirar el estilo. Una restauración protegida se aplaza hasta que sea posible.

Las auras tienen prioridad sobre la decoración: si un icono visible coincide con un ala o el icono de clase, se oculta temporalmente el adorno afectado. La insignia integrada acompaña al icono de clase. Cuando el aura cambia de sitio o desaparece, los adornos recuperan su estado configurado. Las listas vacías no los ocultan. Se comparan rectángulos en espacio de pantalla, incluyendo sus escalas efectivas y un pequeño margen. Si un aura visible no se puede medir, se reservan los laterales ocultando los adornos. Nunca se cambian los anclajes, filtros ni temporizadores de las auras PvP.

Verificado en Lua 5.1: colores de ambas facciones, alfa, cambios del nombre, restauración diferida, colisiones, escalas distintas, combate, contenedores vacíos y regiones restringidas. Falta validación visual en el cliente con EllesmereUI.

## Rediseño PvP heráldico 0.8.8

El modo PvP usa el acabado del diseño de hermandad: doble marco metálico, acento de clase o reacción, icono de clase unido al cuerpo y pequeña insignia de facción integrada. Las alas de hermandad reutilizan la textura de plumas del diseño clásico. Se elimina la segunda barra ampliada que podía tapar el nombre; se conserva la barra real y su textura.

El objetivo se distingue por su contorno, y el recomendado por el oro y un motivo compacto debajo de la barra de lanzamiento si está visible. Se han comprobado nombres, salud, controles, temporizadores, combate y reutilización con Lua 5.1. Falta validar el aspecto final en WoW Forever. Ejecuta `/reload` después de actualizar.

## Nombre externo y escala con EllesmereUI 0.8.7

Cuando está cargado `EllesmereUINameplates`, Tistelti conserva la escala y anchura que gestiona ese módulo. El estilo clásico deja de aplicar su ampliación de escala del 25 % y anchura del 22 % sobre una placa cuyo nombre puede estar alojado fuera de ella. Se conservan los ajustes de fuente, tamaño y posición de ese nombre. Al desactivar Tistelti tampoco se restauran medidas antiguas sobre las elegidas por la otra interfaz.

Sin ese módulo se mantiene la ampliación habitual. Se incluyen los bufos de 0.8.6. Verificado en Lua 5.1 con un nombre en un contenedor externo, cambios de geometría, detección moderna y antigua, combate y desactivación; falta validación visual con la versión y configuración reales del amigo. Referencia consultada: [colocación del nombre en EllesmereUI](https://github.com/EllesmereGaming/EllesmereUI/blob/main/EllesmereUINameplates/EUI_Nameplates_Name.lua).

## Bufos y convivencia con otras interfaces 0.8.6

En el diseño clásico, los beneficios y perjuicios parten de un anclaje situado seis puntos por encima del ala izquierda, siguiendo su tamaño. Se recogen también las listas que aparecen después de crear la decoración y se repone su posición tras actualizaciones de auras. Los controles permanecen junto al nivel.

El posicionador solo modifica placas decoradas por Tistelti. Al retirar las alas o activar PvP compacto restaura los anclajes y capas originales; los marcos protegidos esperan al final del combate. Esto reduce interferencias con otros gestores de placas. La compatibilidad visual concreta con EllesmereUI está pendiente de probar en el cliente. Las pruebas Lua 5.1 cubren listas tardías, dos filas, actualización de anclajes, combate, restauración y regiones restringidas.

## Corrección de errores 0.8.5

El registro real del cliente mostraba una repetición de `Frame:GetPoint(): Can't measure restricted regions` al intentar guardar anclajes de controles. Ahora se comprueban las restricciones parciales de acceso y aspectos prohibidos antes de medirlos. Si no se puede obtener una copia completa y pública, ese marco conserva su colocación nativa. Core aplica las mismas comprobaciones al guardar, recolocar y restaurar auras. Los controles restringidos no se vuelven a medir repetidamente.

La regresión incluye 1.000 actualizaciones de un marco que rechaza las mediciones: no se llama a GetPoint ni se mutan sus anclajes. También se cubren respuestas secretas y clientes sin las comprobaciones preventivas. Ejecuta `/reload` después de actualizar para retirar los manejadores de la versión anterior.

Personalización de placas para grupo y jugadores amistosos, con alas, escudos y colores de clase.

## Modo PvP compacto

Se abre con `/tistelti pvp` o en **Opciones → AddOns → TisteltiPlates → Modo PvP**. Desde 0.8.2 está **desactivado por defecto**; se puede activar con `/tistelti pvp on`. Se respetan las activaciones y desactivaciones ya guardadas. Para apagarlo, usar `/tistelti pvp off`. Conserva el tamaño original con un doble marco metálico y acentos de color. Desactivar el modo recupera el diseño clásico con sus ajustes anteriores. No fuerza CVars ni muestra placas que el juego tenga ocultas.

Los aliados admiten color de clase o azul. Los enemigos llevan acento rojo dentro del marco plateado con barra por clase o roja, según la opción elegida. El icono de clase opcional conserva su acento de clase y se une al lateral izquierdo, con tamaño inicial 22 y selector de 18/22/26/30. El emblema de facción se integra junto a su esquina inferior. El nivel nativo recibe un borde metálico sin duplicar su texto.

### Objetivo actual y recomendado

La opción **Destacar objetivo y recomendado**, activada inicialmente dentro del modo PvP, dibuja un contorno sin relleno alrededor de la barra real. No reemplaza la salud ni tapa el nombre. Conserva el valor guardado de la antigua opción de ampliar.

Tu objetivo enemigo lleva contorno blanco. El recomendado lleva contorno dorado, una marca de 14 y el motivo compacto debajo, dejando sitio a la barra de lanzamiento cuando está visible. Se elimina el rótulo suelto TU OBJETIVO. La recomendación prioriza una calavera real ya existente o un enemigo visible al que estén apuntando al menos dos compañeros. Se estabiliza durante dos segundos mientras siga siendo válido. No infiere sanadores por clase ni emplea criterios de poca vida o curación. Los datos restringidos se omiten; sin información suficiente no se inventa una prioridad.

La marca de recomendación es visual y local: el addon no coloca marcas reales, cambia objetivos ni ataca. Los clics, anclajes de bufos/controles y barras de lanzamiento nativos conservan su comportamiento. La zona clicable mantiene su tamaño original. El destacado desaparece al cambiar objetivo, desaparecer la prioridad, reciclar una placa o desactivar la opción/modo PvP. Falta validar visualmente el resultado dentro de WoW.

Las alas usan las plumas del diseño de hermandad, unidas al icono de clase y al nivel, solo para miembros de tu hermandad de la Alianza. Los matices iniciales son bronce (mérito 1–4), plata (5–9) y oro (10–14); cada tramo permite elegir otro color. Sin datos se usa gris azulado neutro. Son categorías de `TisteltiMerito`, no una afirmación de rango oficial. Brillo y tamaño se ajustan en la misma sección, con vista previa.

Funciona en mundo abierto y permite dibujar en campos de batalla/arenas; las mazmorras y bandas siguen excluidas. Cambiar de modo en combate espera al final para restaurar la geometría anterior. El modo compacto conserva los anclajes nativos de auras y controles. Si la clase no se puede leer, oculta su icono y usa un color de reacción como respaldo.

El ala derecha cede espacio a los controles o pérdidas de control nativos visibles y reaparece al terminar. Las demás alas y el icono de clase ceden solo cuando coinciden con un icono de aura, o no puede medirse un aura visible. Los anclajes de auras, las barras de lanzamiento y los temporizadores se conservan. Los contenedores vacíos u ocultos no ocultan los adornos. Funciona también en combate sin recolocar marcos protegidos.

Comandos: `/tistelti pvp on/off` y `/tistelti enemigos rojo/clase`. `/tistelti vista` mantiene la vista del diseño clásico; la de PvP está en su sección de opciones.

Comprobado con pruebas Lua 5.1 de migración, menús, colores, iconos, combate, instancias, reutilización de placas y restauración. **Pendiente comprobar el aspecto y las restricciones reales dentro de WoW Forever.**

En Opciones, **Prioridad** permite elegir **Grupo/Banda** (todos los compañeros usan el estilo de grupo o banda, incluidos los de tu hermandad) o **Hermandad** (tu propia hermandad conserva su estilo; los demás compañeros usan grupo o banda). Fuera del grupo, los de tu hermandad mantienen su aspecto habitual. Se respetan los interruptores de cada estilo. La selección se guarda y se aplica también en combate; por defecto se conserva la prioridad de Hermandad. **Estilo** sigue eligiendo qué aspecto editas y no cambia la prioridad.

## Instalación

Copia la carpeta `TisteltiPlates` de este repositorio dentro de `_forever_/Interface/AddOns/`. Debe quedar `AddOns/TisteltiPlates/TisteltiPlates.toc`. Activa el addon y las placas amistosas en el juego.

Usa `/tistelti` para acceder a los comandos del addon y `/tistelti vista` para la vista de ejemplo.

Las alas de grupo tienen plumas turquesa y detalles violeta suave, inspirados en el chat de grupo. En banda cambian a naranja ámbar con detalles grafito/acero; hermandad conserva las principales azul y oro. La conversión entre grupo y banda actualiza también las alas y sus brillos durante el combate. En Opciones hay tres estilos independientes: **Grupo, Banda y Hermandad**, cada uno con su interruptor, borde e insignia. Sus vistas previas muestran siempre el estilo seleccionado, aunque estés en una banda. Al actualizar, Banda hereda inicialmente los ajustes anteriores de Grupo y después los guarda por separado. También acepta `/tistelti banda on/off`, `borde banda ...` y `color banda ...`. `/tistelti vista` muestra los dos ejemplos por separado. Las nuevas texturas transparentes se generaron con ImageGen integrado; cada variante incluye PNG fuente, TGA y descripción del prompt en `Media/Wings-Grupo-v1.*` y `Media/Wings-Banda-v1.*`.

## Indicadores de control integrados

Incluye la colocación de indicadores de ForeverCCPosition en las placas decoradas: quedan a la derecha del nivel de Tistelti, con una separación de 8 unidades. Las demás placas conservan sus anclajes originales. Los beneficios y perjuicios normales quedan encima del ala izquierda.

El ala derecha y su brillo se ocultan mientras haya un icono visible de control o pérdida de control, incluidos los stuns, y reaparecen cuando desaparece. Funciona también con la decoración de combate. Los contenedores vacíos no ocultan el ala y las vistas previas conservan ambas alas.

En **Opciones → AddOns → TisteltiPlates**, la casilla **Ocultar ala derecha al mostrar controles** permite activar o desactivar este comportamiento. Está activada por defecto, se guarda entre sesiones y se aplica a las placas de grupo y hermandad sin recargar. Desmarcarla mantiene visibles el ala y su brillo; la posición de los indicadores no cambia.

Usa `/tistelti cc` para consultar si están activadas las placas amistosas y los indicadores de control en amigos. El comando no cambia ninguna opción; Blizzard sigue gestionando los filtros, iconos y duraciones.

No necesita ForeverCCPosition. Desactiva el addon original para evitar que dos addons cambien los mismos anclajes. Si tu copia de ForeverCCPosition contiene otras personalizaciones, consérvalas por separado antes de desactivarla.

Los marcos protegidos no se recolocan durante el combate: se actualizan al terminar. Si el cliente restringe la lectura de visibilidad de un icono, el ala permanece visible.

## Código y datos

`TisteltiPlates/Honor.lua`, `TisteltiPlates/Prioridad.lua`, `TisteltiPlates/PvP.lua`, `TisteltiPlates/CCPosition.lua` y `TisteltiPlates/Core.lua` contienen el código; el manifiesto TOC define el orden de carga. Las texturas necesarias están en `TisteltiPlates/Media/`.

El addon se mantiene separado de TisteltiGuild y no lo requiere. La configuración se guarda en `TisteltiPlatesDB`. Este repositorio no incluye SavedVariables, datos de jugadores ni credenciales.

## Estado

Base importada del paquete `TisteltiPlates-0.7.8-para-compartir.zip`. Incluye la corrección de restauración de color cuando una placa se retira y su unidad ya no está disponible, también tras una limpieza aplazada durante el combate.

Comprobado en Lua 5.1 con unidades ausentes, inexistentes, secretas y válidas, y con restauración aplazada tras el combate. Queda comprobar el resultado dentro del juego.

## Pruebas de la integración

Desde la raíz del repositorio, ejecuta `lua tests/test_cc.lua` (Lua 5.1 o posterior). La prueba usa marcos simulados y cubre la aparición y desaparición del icono, brillo, padres ocultos, transparencia, visibilidad restringida, combate, reutilización de placas, anclajes, diagnóstico y la corrección de placas sin unidad.

Las pruebas simuladas no sustituyen la comprobación en WoW Forever: recarga la interfaz, revisa `/tistelti cc` y comprueba que el ala derecha desaparece al mostrarse un control sobre un aliado y vuelve al terminar.

`lua tests/test_wings.lua` comprueba las tres opciones de estilo y sus vistas previas estando en banda, los ajustes independientes, la migración de configuración y la selección de grupo/banda.

`lua tests/test_pvp.lua` comprueba la integración real de Core, CC y PvP, las opciones, los colores, cambios de modo, instancias y reciclaje. Incluye aparición/desaparición de controles en combate, contenedores vacíos/ocultos, visibilidad restringida y conservación de anclajes y temporizadores nativos de habilidades y lanzamientos. Pendiente validar el resultado visual en WoW Forever.

La misma prueba cubre el tamaño y posición del icono de clase y la ampliación visual en combate, actualización inmediata de vida y restauración sin cambios de geometría nativa. `lua tests/test_priority.lua` comprueba consenso de grupo, calavera existente, estabilidad, retirada de candidatos inválidos y datos restringidos.
