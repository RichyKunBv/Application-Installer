# Application Installer

Un asistente de terminal para instalar aplicaciones de Linux distribuidas en archivos `.zip` o `.tar.gz` de forma fácil y consistente.

-----

## ¿Qué Hace? ⚙️

Este script toma un archivo comprimido y lo instala correctamente en tu sistema. Sus principales funciones son:

  * **Instala aplicaciones** desde un archivo `.zip` o `.tar.gz`.
  * **Analiza el contenido** y te ayuda a seleccionar el archivo ejecutable y el icono.
  * **Copia los archivos** a una ubicación limpia y ordenada (`~/Applications` o `/opt`).
  * **Crea un acceso directo** en tu menú de aplicaciones.
  * **Añade un comando a tu terminal** para que puedas ejecutar la app desde cualquier lugar.
  * **Se actualiza a sí mismo** para tener siempre la última versión.

### Desinstala aplicaciones facilmente
 * **Solo con pocos clicks** preciona 2 y elije la aplicacion que quieras desinstalar
 * (Solo funciona con aplicaciones instaladas desde este script ya que hace un historial de instalacion localmente conforme a las que instalas)

-----

## ¿Cómo Funciona? 🚀

1.  **Descarga y prepara el script:**

    ```bash
    wget https://raw.githubusercontent.com/RichyKunBv/Application-Installer-in-ZIP/main/instalar-app.sh
    chmod +x instalar-app.sh
    ```

2.  **Ejecútalo en tu terminal:**

    ```bash
    ./instalar-app.sh
    ```

3.  **Usa el menú:**

      * Selecciona la **Opción 1** para instalar una aplicación.
      * **Arrastra el archivo** `.zip` o `.tar.gz` que descargaste a la ventana de la terminal y presiona `Enter`.
      * **Sigue los pasos** que el asistente te indique.

-----

## Estado del Proyecto 🚧

El proyecto esta en pañales, aunque tiene compatibilidad con algunas aplicaciones, no con la mayoria o todas asi que si notas que no funciona con alguna te recomiendo que hagas un Branch (creo asi se llaman :v)
