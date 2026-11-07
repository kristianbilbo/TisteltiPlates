# TisteltiPlates

Addon para WoW Forever (interfaz 16001). Versión inicial del repositorio: **0.7.8**.

Personalización de placas para grupo y jugadores amistosos, con alas, escudos y colores de clase.

## Instalación

Copia la carpeta `TisteltiPlates` de este repositorio dentro de `_forever_/Interface/AddOns/`. Debe quedar `AddOns/TisteltiPlates/TisteltiPlates.toc`. Activa el addon y las placas amistosas en el juego.

Usa `/tistelti` para acceder a los comandos del addon y `/tistelti vista` para la vista de ejemplo.

## Código y datos

`TisteltiPlates/Honor.lua` y `TisteltiPlates/Core.lua` contienen el código; el manifiesto TOC define el orden de carga. Las texturas necesarias están en `TisteltiPlates/Media/`.

El addon se mantiene separado de TisteltiGuild y no lo requiere. La configuración se guarda en `TisteltiPlatesDB`. Este repositorio no incluye SavedVariables, datos de jugadores ni credenciales.

## Estado

Código importado del paquete `TisteltiPlates-0.7.8-para-compartir.zip` sin modificar su comportamiento. La comprobación de archivos y manifiesto no sustituye las pruebas dentro del juego.
