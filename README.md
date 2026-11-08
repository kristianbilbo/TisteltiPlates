# TisteltiPlates

Addon para WoW Forever (interfaz 16001). Versión actual: **0.8.1**.

Personalización de placas para grupo y jugadores amistosos, con alas, escudos y colores de clase.

## Modo PvP compacto

Se abre con `/tistelti pvp` o en **Opciones → AddOns → TisteltiPlates → Modo PvP**. Está activado inicialmente: conserva el tamaño original y sustituye las alas grandes por un marco con neón y un emblema de facción pequeño pegado al borde. Desactivar el modo recupera el diseño clásico con sus ajustes anteriores. No fuerza CVars ni muestra placas que el juego tenga ocultas.

Los aliados admiten color de clase o azul. Los enemigos admiten **barra, marco y neón por clase** o **los tres rojos**. El icono de clase opcional conserva siempre su propio contorno neón de clase, incluso cuando la barra es roja. Se mantiene el emblema de facción, sin sustituirlo todavía por los escudos de mérito de los bocetos.

Las alas son trazos pequeños de un solo color, pegados a ambos lados, solo para miembros de tu hermandad de la Alianza. Los colores iniciales son bronce (mérito 1–4), plata (5–9) y oro (10–14); cada tramo permite elegir otro color. Sin datos se usa gris azulado neutro. Son categorías de `TisteltiMerito`, no una afirmación de rango oficial. Brillo y tamaño de alas se ajustan en la misma sección, con vista previa.

Funciona en mundo abierto y permite dibujar en campos de batalla/arenas; las mazmorras y bandas siguen excluidas. Cambiar de modo en combate espera al final para restaurar la geometría anterior. El modo compacto conserva los anclajes nativos de auras y controles. Si la clase no se puede leer, oculta su icono y usa un color de reacción como respaldo.

En 0.8.1 se evita que el ala derecha y el icono de clase compactos tapen indicadores de control o pérdida de control: ambos se ocultan mientras haya un icono nativo visible y recuperan sus opciones al terminar. El ala izquierda, los anclajes de auras, las barras de lanzamiento y los temporizadores de habilidades se conservan. Los contenedores vacíos u ocultos no ocultan la decoración. La comprobación funciona también en combate, sin recolocar marcos protegidos.

Comandos: `/tistelti pvp on/off` y `/tistelti enemigos rojo/clase`. `/tistelti vista` mantiene la vista del diseño clásico; la de PvP está en su sección de opciones.

Comprobado con pruebas Lua 5.1 de migración, menús, colores, iconos, combate, instancias, reutilización de placas y restauración. **Pendiente comprobar el aspecto y las restricciones reales dentro de WoW Forever.**

En Opciones, **Prioridad** permite elegir **Grupo/Banda** (todos los compañeros usan el estilo de grupo o banda, incluidos los de tu hermandad) o **Hermandad** (tu propia hermandad conserva su estilo; los demás compañeros usan grupo o banda). Fuera del grupo, los de tu hermandad mantienen su aspecto habitual. Se respetan los interruptores de cada estilo. La selección se guarda y se aplica también en combate; por defecto se conserva la prioridad de Hermandad. **Estilo** sigue eligiendo qué aspecto editas y no cambia la prioridad.

## Instalación

Copia la carpeta `TisteltiPlates` de este repositorio dentro de `_forever_/Interface/AddOns/`. Debe quedar `AddOns/TisteltiPlates/TisteltiPlates.toc`. Activa el addon y las placas amistosas en el juego.

Usa `/tistelti` para acceder a los comandos del addon y `/tistelti vista` para la vista de ejemplo.

Las alas de grupo tienen plumas turquesa y detalles violeta suave, inspirados en el chat de grupo. En banda cambian a naranja ámbar con detalles grafito/acero; hermandad conserva las principales azul y oro. La conversión entre grupo y banda actualiza también las alas y sus brillos durante el combate. En Opciones hay tres estilos independientes: **Grupo, Banda y Hermandad**, cada uno con su interruptor, borde e insignia. Sus vistas previas muestran siempre el estilo seleccionado, aunque estés en una banda. Al actualizar, Banda hereda inicialmente los ajustes anteriores de Grupo y después los guarda por separado. También acepta `/tistelti banda on/off`, `borde banda ...` y `color banda ...`. `/tistelti vista` muestra los dos ejemplos por separado. Las nuevas texturas transparentes se generaron con ImageGen integrado; cada variante incluye PNG fuente, TGA y descripción del prompt en `Media/Wings-Grupo-v1.*` y `Media/Wings-Banda-v1.*`.

## Indicadores de control integrados

Incluye la colocación de indicadores de ForeverCCPosition: quedan a la derecha del nivel, con una separación de 8 unidades. En las placas decoradas se usa el distintivo de nivel de Tistelti; las demás conservan la colocación junto al nivel nativo. Los beneficios y perjuicios normales siguen encima de la placa.

El ala derecha y su brillo se ocultan mientras haya un icono visible de control o pérdida de control, incluidos los stuns, y reaparecen cuando desaparece. Funciona también con la decoración de combate. Los contenedores vacíos no ocultan el ala y las vistas previas conservan ambas alas.

En **Opciones → AddOns → TisteltiPlates**, la casilla **Ocultar ala derecha al mostrar controles** permite activar o desactivar este comportamiento. Está activada por defecto, se guarda entre sesiones y se aplica a las placas de grupo y hermandad sin recargar. Desmarcarla mantiene visibles el ala y su brillo; la posición de los indicadores no cambia.

Usa `/tistelti cc` para consultar si están activadas las placas amistosas y los indicadores de control en amigos. El comando no cambia ninguna opción; Blizzard sigue gestionando los filtros, iconos y duraciones.

No necesita ForeverCCPosition. Desactiva el addon original para evitar que dos addons cambien los mismos anclajes. Si tu copia de ForeverCCPosition contiene otras personalizaciones, consérvalas por separado antes de desactivarla.

Los marcos protegidos no se recolocan durante el combate: se actualizan al terminar. Si el cliente restringe la lectura de visibilidad de un icono, el ala permanece visible.

## Código y datos

`TisteltiPlates/Honor.lua`, `TisteltiPlates/PvP.lua`, `TisteltiPlates/CCPosition.lua` y `TisteltiPlates/Core.lua` contienen el código; el manifiesto TOC define el orden de carga. Las texturas necesarias están en `TisteltiPlates/Media/`.

El addon se mantiene separado de TisteltiGuild y no lo requiere. La configuración se guarda en `TisteltiPlatesDB`. Este repositorio no incluye SavedVariables, datos de jugadores ni credenciales.

## Estado

Base importada del paquete `TisteltiPlates-0.7.8-para-compartir.zip`. Incluye la corrección de restauración de color cuando una placa se retira y su unidad ya no está disponible, también tras una limpieza aplazada durante el combate.

Comprobado en Lua 5.1 con unidades ausentes, inexistentes, secretas y válidas, y con restauración aplazada tras el combate. Queda comprobar el resultado dentro del juego.

## Pruebas de la integración

Desde la raíz del repositorio, ejecuta `lua tests/test_cc.lua` (Lua 5.1 o posterior). La prueba usa marcos simulados y cubre la aparición y desaparición del icono, brillo, padres ocultos, transparencia, visibilidad restringida, combate, reutilización de placas, anclajes, diagnóstico y la corrección de placas sin unidad.

Las pruebas simuladas no sustituyen la comprobación en WoW Forever: recarga la interfaz, revisa `/tistelti cc` y comprueba que el ala derecha desaparece al mostrarse un control sobre un aliado y vuelve al terminar.

`lua tests/test_wings.lua` comprueba las tres opciones de estilo y sus vistas previas estando en banda, los ajustes independientes, la migración de configuración y la selección de grupo/banda.

`lua tests/test_pvp.lua` comprueba la integración real de Core, CC y PvP, las opciones, los colores, cambios de modo, instancias y reciclaje. Incluye aparición/desaparición de controles en combate, contenedores vacíos/ocultos, visibilidad restringida y conservación de anclajes y temporizadores nativos de habilidades y lanzamientos. Pendiente validar el resultado visual en WoW Forever.
