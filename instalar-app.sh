#!/bin/bash

# ##################################################################
#                  Install-App v0.2
# Un asistente universal y consistente para instalar aplicaciones
# desde archivos .zip o .tar.gz.
# Filosofía: Para flojos como yo que les gusta lo simple.
# ##################################################################

# --- Configuración de Colores ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

# --- Funciones de Ayuda ---
info() { echo -e "${C_BLUE}INFO:${C_RESET} $1"; }
success() { echo -e "${C_GREEN}ÉXITO:${C_RESET} $1"; }
warn() { echo -e "${C_YELLOW}AVISO:${C_RESET} $1"; }
error() { echo -e "${C_RED}ERROR:${C_RESET} $1" >&2; exit 1; }

# ##################################################################
#                       INICIO DEL SCRIPT
# ##################################################################

info "Iniciando el Asistente de Instalación de Aplicaciones..."

# --- 1. Verificaciones Iniciales ---
if [ -z "$1" ]; then
    error "Debes proporcionar la ruta a un archivo .zip o .tar.gz.\nUso: $0 /ruta/al/archivo"
fi

ARCHIVE_FILE="$1"

if [ ! -f "$ARCHIVE_FILE" ]; then
    error "El archivo '$ARCHIVE_FILE' no existe."
fi

# --- 2. Detección de Formato y Descompresión ---
TEMP_DIR=$(mktemp -d -t install-app-XXXXXX)
# La 'trap' asegura que el directorio temporal se borre al salir, incluso si hay un error.
trap 'info "Limpiando archivos temporales..."; rm -rf "$TEMP_DIR"' EXIT

info "Descomprimiendo '$ARCHIVE_FILE'..."
case "$ARCHIVE_FILE" in
    *.zip)
        if ! command -v unzip &> /dev/null; then error "El comando 'unzip' no está instalado."; fi
        unzip -q "$ARCHIVE_FILE" -d "$TEMP_DIR" || error "No se pudo descomprimir el archivo ZIP."
        ;;
    *.tar.gz|*.tgz)
        if ! command -v tar &> /dev/null; then error "El comando 'tar' no está instalado."; fi
        tar -xzf "$ARCHIVE_FILE" -C "$TEMP_DIR" || error "No se pudo descomprimir el archivo TAR.GZ."
        ;;
    *)
        error "Formato de archivo no soportado. Usa .zip o .tar.gz."
        ;;
esac

# Navegar al directorio temporal y manejar carpetas anidadas
cd "$TEMP_DIR" || error "No se pudo acceder al directorio temporal."
# Si el archivo descomprimido contiene solo una carpeta, entramos en ella para simplificar.
NUM_ITEMS=$(ls -1 . | wc -l)
if [ "$NUM_ITEMS" -eq 1 ] && [ -d "$(ls -1 .)" ]; then
    info "El archivo contenía una sola carpeta, accediendo a ella."
    cd "$(ls -1 .)" || error "No se pudo acceder a la subcarpeta."
fi

# --- 3. Análisis Interactivo ---
info "Analizando el contenido de la aplicación..."

# Buscar ejecutables
readarray -t EXECUTABLES < <(find . -type f -executable -not -name "*.so*" 2>/dev/null)
if [ ${#EXECUTABLES[@]} -eq 0 ]; then
    error "No se encontraron archivos ejecutables."
fi

# Menú para seleccionar el ejecutable principal
info "Se encontraron los siguientes archivos ejecutables. Por favor, selecciona el principal:"
PS3="Selecciona el número del ejecutable: "
select EXEC_PATH in "${EXECUTABLES[@]}"; do
    if [[ -n "$EXEC_PATH" ]]; then
        break
    else
        warn "Selección inválida. Intenta de nuevo."
    fi
done

# Buscar iconos (opcional)
readarray -t ICONS < <(find . -type f \( -name "*.png" -o -name "*.svg" \) 2>/dev/null)
ICON_PATH="" # Por defecto no hay icono

if [ ${#ICONS[@]} -gt 0 ];
then
    info "Se encontraron iconos. Puedes seleccionar uno para el menú (opcional)."
    ICONS+=("No seleccionar ningún icono")
    PS3="Selecciona el número del icono (o presiona Enter para omitir): "
    select ICON_CANDIDATE in "${ICONS[@]}"; do
        if [[ -n "$ICON_CANDIDATE" && "$ICON_CANDIDATE" != "No seleccionar ningún icono" ]]; then
            ICON_PATH="$ICON_CANDIDATE"
            break
        elif [[ "$ICON_CANDIDATE" == "No seleccionar ningún icono" ]]; then
            info "Se omitió la selección de icono."
            break
        else
             warn "Selección inválida. Intenta de nuevo."
        fi
    done
else
    warn "No se encontraron archivos de icono."
fi


# --- 4. Diálogo de Instalación ---
echo -e "\n${C_CYAN}--- Configuración de la Instalación ---${C_RESET}"
read -p "Introduce el nombre para la aplicación (ej. Visual Studio Code): " APP_NAME

APP_DIR_NAME=$(echo "$APP_NAME" | sed 's/ /-/g') # ej. Visual Studio Code -> Visual-Studio-Code

info "Elige una ubicación para la instalación:"
INSTALL_OPTIONS=(
    "Solo para el usuario actual (~/Applications) - Recomendado"
    "Para todos los usuarios del sistema (/opt) - Requiere Sudo"
    "Especificar una ruta personalizada"
)
PS3="Selecciona una opción: "
select opt in "${INSTALL_OPTIONS[@]}"; do
    case $REPLY in
        1)
            INSTALL_DIR="$HOME/Applications/$APP_DIR_NAME"
            BIN_LINK_DIR="$HOME/.local/bin"
            DESKTOP_DIR="$HOME/.local/share/applications"
            NEEDS_SUDO=false
            break
            ;;
        2)
            INSTALL_DIR="/opt/$APP_DIR_NAME"
            BIN_LINK_DIR="/usr/local/bin"
            DESKTOP_DIR="/usr/share/applications"
            NEEDS_SUDO=true
            break
            ;;
        3)
            read -p "Introduce la ruta de instalación completa (sin el nombre de la app): " CUSTOM_PATH
            INSTALL_DIR="${CUSTOM_PATH%/}/$APP_DIR_NAME"
            BIN_LINK_DIR="$HOME/.local/bin"
            DESKTOP_DIR="$HOME/.local/share/applications"
            warn "Los enlaces para la terminal y el menú se crearán solo para el usuario actual."
            NEEDS_SUDO=false
            break
            ;;
        *)
            warn "Opción inválida."
            ;;
    esac
done

# --- 5. Proceso de Instalación ---
info "Preparando para instalar..."

if [ "$NEEDS_SUDO" = true ] && [ "$EUID" -ne 0 ]; then
    info "Se requieren privilegios de administrador. Volviendo a ejecutar con sudo..."
    # Ejecuta de nuevo el script con sudo, pero con un flag para no repetir las preguntas.
    # Esta es una forma avanzada y segura de manejar sudo.
    sudo bash -c "$(cat $0)" -- "$@" --sudo_run
    exit $?
fi
# Si ya estamos en modo sudo, saltamos las preguntas.
if [[ " $* " == *" --sudo_run "* ]]; then
    info "Ejecutando en modo Sudo..."
fi

# Creación de directorios
info "Creando directorios de destino..."
mkdir -p "$INSTALL_DIR" || error "No se pudo crear el directorio de instalación: $INSTALL_DIR"
mkdir -p "$BIN_LINK_DIR"
mkdir -p "$DESKTOP_DIR"

info "Copiando archivos de la aplicación a '$INSTALL_DIR'..."
# rsync es robusto para copiar archivos.
rsync -a --progress . "$INSTALL_DIR/" || error "Fallo al copiar los archivos."

# Crear enlace simbólico para la terminal
APP_COMMAND_NAME=$(basename "$EXEC_PATH" | sed 's/\.sh$//') # quita .sh si lo tiene
info "Creando comando de terminal: '$APP_COMMAND_NAME'..."
ln -sf "$INSTALL_DIR/$EXEC_PATH" "$BIN_LINK_DIR/$APP_COMMAND_NAME"

# Crear archivo .desktop para el menú de aplicaciones
DESKTOP_FILE_PATH="$DESKTOP_DIR/$APP_DIR_NAME.desktop"
info "Creando archivo de menú en '$DESKTOP_FILE_PATH'..."

# Genera el contenido del archivo .desktop
cat > "$DESKTOP_FILE_PATH" << EOL
[Desktop Entry]
Version=1.0
Name=$APP_NAME
Comment=$APP_NAME (Aplicacion instalada gracias a RichyKunBv <3)
Exec=$BIN_LINK_DIR/$APP_COMMAND_NAME
Terminal=false
Type=Application
Categories=Utility;
EOL

# Añade el icono si fue seleccionado
if [ -n "$ICON_PATH" ]; then
    echo "Icon=$INSTALL_DIR/$ICON_PATH" >> "$DESKTOP_FILE_PATH"
fi

# Darle permisos de ejecución al archivo .desktop
chmod +x "$DESKTOP_FILE_PATH"

# --- 6. Confirmación Final ---
echo
success "¡Instalación completada!"
echo "--------------------------------------------------"
echo -e " Aplicación:    ${C_YELLOW}$APP_NAME${C_RESET}"
echo -e " Instalado en:    ${C_YELLOW}$INSTALL_DIR${C_RESET}"
echo -e " Comando:         ${C_YELLOW}$APP_COMMAND_NAME${C_RESET}"
echo "--------------------------------------------------"
echo "Ya puedes buscar la aplicación en tu menú o ejecutarla desde la terminal."

exit 0
