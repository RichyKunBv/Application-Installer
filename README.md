# 🐧 Gestor de Aplicaciones para Linux

[![Versión](https://img.shields.io/badge/Versión-1.0-blue.svg)](https://github.com/RichyKunBv/Application-Installer-in-ZIP)
[![Licencia](https://img.shields.io/badge/Licencia-GPL--3.0-green.svg)](https://github.com/RichyKunBv/Application-Installer-in-ZIP/blob/main/LICENSE)
[![Lenguaje](https://img.shields.io/badge/Lenguaje-Bash-lightgrey.svg)](https://github.com/RichyKunBv/Application-Installer-in-ZIP)

Un script de terminal para instalar, gestionar y desinstalar aplicaciones portátiles de Linux de forma sencilla, inteligente y sin pereza.

---

## 🤔 ¿Qué es esto?

Este proyecto nació de la pereza de tener que instalar manualmente aplicaciones que vienen en archivos comprimidos (`.zip`, `.tar.gz`, etc.). En lugar de mover carpetas, crear accesos directos y enlaces a mano, este script lo automatiza todo a través de un menú interactivo en la terminal.

Ha evolucionado a un gestor completo que no solo instala, sino que también lleva un registro de tus aplicaciones, las desinstala limpiamente y se mantiene actualizado.

## ✨ Características Principales

* **INSTALADOR INTELIGENTE:**
    * 🧠 **Análisis de Dependencias:** Revisa el ejecutable y te avisa si te faltan librerías (`.so`) para que la aplicación funcione.
    * 🔎 **Búsqueda Relevante:** Filtra los archivos para mostrarte primero los ejecutables e iconos más probables, evitando el desorden.
    * ⚠️ **Detector de Duplicados:** Te advierte si intentas instalar una aplicación que ya tienes registrada.

* **GESTOR COMPLETO:**
    * ✅ **Instalación Guiada:** Te lleva paso a paso para instalar, crear accesos directos en el menú y comandos en la terminal.
    * ❌ **Desinstalación Segura:** Borra todos los archivos de una aplicación. ¡Incluso detecta si la app está en ejecución y te ofrece cerrarla!
    * 📋 **Listado de Apps:** Muestra un resumen de todas las aplicaciones que has instalado con la herramienta.

* **MÁXIMA COMPATIBILIDAD:**
    * 📦 **Soporte Amplio de Formatos:** Funciona con `.zip`, `.tar.gz`, `.tar.xz`, `.tar.bz2`, `.7z` y hasta con **binarios simples** sin comprimir.
    * 🔄 **Auto-Actualización:** Se mantiene al día con la última versión directamente desde GitHub.

---

## 🚀 Instalación y Uso

1.  **Descarga el script** con `wget` o `curl`:
    ```bash
    wget [https://raw.githubusercontent.com/RichyKunBv/Application-Installer-in-ZIP/main/instalar-app.sh](https://raw.githubusercontent.com/RichyKunBv/Application-Installer-in-ZIP/main/instalar-app.sh)
    ```
2.  **Dale permisos de ejecución:**
    ```bash
    chmod +x instalar-app.sh
    ```
3.  **Ejecútalo:**
    ```bash
    ./instalar-app.sh
    ```
4.  **Usa el menú interactivo** para instalar, desinstalar, listar o actualizar tus aplicaciones.

---

## 🛠️ Dependencias

Para que todas las funciones operen correctamente, asegúrate de tener instalados los siguientes paquetes:
* `curl` o `wget` (para la auto-actualización)
* `unzip` (para archivos `.zip`)
* `tar` (para archivos `.tar.*`)
* `p7zip-full` (en Debian/Ubuntu) o `p7zip` (en Arch/Fedora) (para archivos `.7z`)

---

## 📝 Estado del Proyecto

**Versión 1.0 - Estable.** El script es ahora un gestor de aplicaciones maduro y con funcionalidades completas.
