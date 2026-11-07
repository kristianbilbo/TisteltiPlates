# TisteltiPlates

Addon para WoW Forever (interfaz 16001). Versión inicial del repositorio: **0.7.8**.

Personalización de placas para grupo y jugadores amistosos, con alas, escudos y colores de clase.

## Instalación

Copia la carpeta `TisteltiPlates` de este repositorio dentro de `_forever_/Interface/AddOns/`. Debe quedar `AddOns/TisteltiPlates/TisteltiPlates.toc`. Activa el addon y las placas amistosas en el juego.

Usa `/tistelti` para acceder a los comandos del addon y `/tistelti vista` para la vista de ejemplo.

## Indicadores de control integrados

Incluye la colocación de indicadores de ForeverCCPosition: quedan a la derecha del nivel, con una separación de 8 unidades. En las placas decoradas se usa el distintivo de nivel de Tistelti; las demás conservan la colocación junto al nivel nativo. Los beneficios y perjuicios normales siguen encima de la placa.

El ala derecha y su brillo se ocultan mientras haya un icono visible de control o pérdida de control, incluidos los stuns, y reaparecen cuando desaparece. Funciona también con la decoración de combate. Los contenedores vacíos no ocultan el ala y las vistas previas conservan ambas alas.

En **Opciones → AddOns → TisteltiPlates**, la casilla **Ocultar ala derecha al mostrar controles** permite activar o desactivar este comportamiento. Está activada por defecto, se guarda entre sesiones y se aplica a las placas de grupo y hermandad sin recargar. Desmarcarla mantiene visibles el ala y su brillo; la posición de los indicadores no cambia.

Usa `/tistelti cc` para consultar si están activadas las placas amistosas y los indicadores de control en amigos. El comando no cambia ninguna opción; Blizzard sigue gestionando los filtros, iconos y duraciones.

No necesita ForeverCCPosition. Desactiva el addon original para evitar que dos addons cambien los mismos anclajes. Si tu copia de ForeverCCPosition contiene otras personalizaciones, consérvalas por separado antes de desactivarla.

Los marcos protegidos no se recolocan durante el combate: se actualizan al terminar. Si el cliente restringe la lectura de visibilidad de un icono, el ala permanece visible.

## Nombre completo al pasar el cursor

En las placas decoradas de grupo y hermandad, pasar el cursor por la barra o el nombre amplía el ancho lo necesario para que quepa el nombre completo. Mantiene el tamaño de las letras, el espacio de los textos de salud y los anclajes de las alas, el nivel y los controles. Al retirar el cursor recupera el ancho habitual. Los nombres que ya caben no amplían la placa.

Durante el combate solo se redimensionan los marcos que el cliente permite modificar. Si una placa está protegida, la ampliación o restauración pendiente espera hasta que termine el bloqueo. Si las medidas del nombre son secretas o no están disponibles, se conserva el ancho habitual.

Prueba simulada específica: `lua tests/test_hover.lua`. Pendiente de verificar dentro del juego con nombres largos y distintos tamaños de interfaz.

## Código y datos

`TisteltiPlates/Honor.lua`, `TisteltiPlates/CCPosition.lua`, `TisteltiPlates/HoverWidth.lua` y `TisteltiPlates/Core.lua` contienen el código; el manifiesto TOC define el orden de carga. Las texturas necesarias están en `TisteltiPlates/Media/`.

El addon se mantiene separado de TisteltiGuild y no lo requiere. La configuración se guarda en `TisteltiPlatesDB`. Este repositorio no incluye SavedVariables, datos de jugadores ni credenciales.

## Estado

Base importada del paquete `TisteltiPlates-0.7.8-para-compartir.zip`. Incluye la corrección de restauración de color cuando una placa se retira y su unidad ya no está disponible, también tras una limpieza aplazada durante el combate.

Comprobado en Lua 5.1 con unidades ausentes, inexistentes, secretas y válidas, y con restauración aplazada tras el combate. Queda comprobar el resultado dentro del juego.

## Pruebas de la integración

Desde la raíz del repositorio, ejecuta `lua tests/test_cc.lua` (Lua 5.1 o posterior). La prueba usa marcos simulados y cubre la aparición y desaparición del icono, brillo, padres ocultos, transparencia, visibilidad restringida, combate, reutilización de placas, anclajes, diagnóstico y la corrección de placas sin unidad.

Las pruebas simuladas no sustituyen la comprobación en WoW Forever: recarga la interfaz, revisa `/tistelti cc` y comprueba que el ala derecha desaparece al mostrarse un control sobre un aliado y vuelve al terminar.
