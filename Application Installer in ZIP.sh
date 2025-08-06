#!/bin/bash

# ##################################################################
#                  Install-from-ZIP v1.0
# Un asistente universal para instalar aplicaciones desde archivos .zip
# Creado por Gemini, basado en una idea del usuario.
# ##################################################################

# --- Configuración de Colores para la Salida ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

# --- Funciones de Ayuda ---
info() {
    echo -e "${C_BLUE}INFO:${C_RESET} $1"
}

success() {
    echo -e "${C_GREEN}SUCCESS:${C_RESET} $1"
}

warn() {
    echo -e "${C_YELLOW}WARN:${C_RESET} $1"
}

error() {
    echo -e "${C_RED}ERROR:${C_RESET} $1" >&2
    exit 1
}

# ##################################################################
#                       INICIO DEL SCRIPT
# ##################################################################

# --- 1. Verificaciones Iniciales ---
info "Iniciando el Asistente de Instalación desde ZIP..."

# ¿Se proveyó un archivo?
if [ -z "$1" ]; then
    error "Debes proporcionar la ruta a un archivo .zip. Uso: $0 /ruta/al/archivo.zip"
fi

ZIP_FILE="$1"

# ¿Existe el archivo?
if [ ! -f "$ZIP_FILE" ]; then
    error "El archivo '$ZIP_FILE' no existe."
fi

# ¿Tenemos el comando 'unzip'?
if ! command -v unzip &> /dev/null; then
    error "El comando 'unzip' no está instalado. Por favor, instálalo con el gestor de paquetes de tu distribución (ej. sudo apt install unzip)."
fi

# --- 2. Crear y Limpiar Directorio Temporal ---
# Creamos un directorio temporal que se limpiará automáticamente al salir.
TEMP_DIR=$(mktemp -d -t install-from-zip-XXXXXX)
trap 'info "Limpiando archivos temporales..."; rm -rf "$TEMP_DIR"' EXIT

info "Descomprimiendo '$ZIP_FILE' en un directorio temporal..."
unzip -q "$ZIP_FILE" -d "$TEMP_DIR" || error "No se pudo descomprimir el archivo ZIP."

# Movemos los archivos a un subdirectorio predecible si están dentro de otra carpeta
# Esto soluciona el caso de ZIPs que contienen una única carpeta en su interior.
NUM_ITEMS=$(ls -1 "$TEMP_DIR" | wc -l)
if [ "$NUM_ITEMS" -eq 1 ]; then
    INNER_DIR=$(ls -1 "$TEMP_DIR")
    if [ -d "$TEMP_DIR/$INNER_DIR" ]; then
        info "El ZIP contiene una sola carpeta. Usando su contenido."
        mv "$TEMP_DIR/$INNER_DIR"/* "$TEMP_DIR/"
        rmdir "$TEMP_DIR/$INNER_DIR"
    fi
fi


# --- 3. Análisis Interactivo (El Cerebro) ---
info "Analizando el contenido de la aplicación..."
cd "$TEMP_DIR" || error "No se pudo acceder al directorio temporal."

# Buscar ejecutables
readarray -t EXECUTABLES < <(find . -type f -executable -not -name "*.so*" 2>/dev/null)

if [ ${#EXECUTABLES[@]} -eq 0 ]; then
    error "No se encontraron archivos ejecutables en el ZIP."
fi

# Menú para seleccionar el ejecutable principal
info "Se encontraron los siguientes archivos ejecutables. Por favor, selecciona el principal:"
PS3="Selecciona el número del ejecutable principal: "
select EXEC_PATH in "${EXECUTABLES[@]}"; do
    if [[ -n "$EXEC_PATH" ]]; then
        break
    else
        warn "Selección inválida. Intenta de nuevo."
    fi
done

# Buscar iconos
readarray -t ICONS < <(find . -type f \( -name "*.png" -o -name "*.svg" \) 2>/dev/null)
ICON_PATH="" # Por defecto no hay icono

if [ ${#ICONS[@]} -gt 0 ]; then
    info "Se encontraron los siguientes iconos. Puedes seleccionar uno (opcional)."
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
read -p "Introduce el nombre para la aplicación (ej. My Awesome App): " APP_NAME

# Convertir nombre a un formato para directorios (ej. My Awesome App -> My-Awesome-App)
APP_DIR_NAME=$(echo "$APP_NAME" | sed 's/ /-/g')

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
            read -p "Introduce la ruta de instalación completa: " CUSTOM_PATH
            INSTALL_DIR="${CUSTOM_PATH%/}/$APP_DIR_NAME" # Eliminar / al final si existe
            BIN_LINK_DIR="$HOME/.local/bin" # Por defecto, el enlace va al usuario
            DESKTOP_DIR="$HOME/.local/share/applications"
            warn "Los enlaces para la terminal y el menú se crearán para el usuario actual."
            NEEDS_SUDO=false # Asumimos que el usuario tiene permisos para la ruta custom
            break
            ;;
        *)
            warn "Opción inválida."
            ;;
    esac
done

# --- 5. Instalación Atómica ---
info "Preparando para instalar..."

# Manejo de Sudo
if [ "$NEEDS_SUDO" = true ] && [ "$EUID" -ne 0 ]; then
    info "Se requieren privilegios de administrador. Volviendo a ejecutar con sudo..."
    # Vuelve a ejecutar el script con sudo, pasando los mismos argumentos.
    sudo bash "$0" "$@"
    exit $?
fi

# Crear directorios necesarios
info "Creando directorios de destino..."
mkdir -p "$INSTALL_DIR" || error "No se pudo crear el directorio de instalación: $INSTALL_DIR"
mkdir -p "$BIN_LINK_DIR"
mkdir -p "$DESKTOP_DIR"

info "Copiando archivos de la aplicación a '$INSTALL_DIR'..."
# Usamos rsync para mejor manejo de archivos y permisos
rsync -a --progress . "$INSTALL_DIR/" || error "Fallo al copiar los archivos."

# Crear enlace simbólico para la terminal
APP_COMMAND=$(basename "$EXEC_PATH")
info "Creando enlace simbólico en '$BIN_LINK_DIR/$APP_COMMAND'..."
ln -sf "$INSTALL_DIR/$EXEC_PATH" "$BIN_LINK_DIR/$APP_COMMAND"

# Crear archivo .desktop para el menú de aplicaciones
DESKTOP_FILE_PATH="$DESKTOP_DIR/$APP_DIR_NAME.desktop"
info "Creando archivo de menú en '$DESKTOP_FILE_PATH'..."

# La magia para crear el archivo .desktop
cat > "$DESKTOP_FILE_PATH" << EOL
[Desktop Entry]
Version=1.0
Name=$APP_NAME
Comment=Instalado con el asistente Install-from-ZIP
Exec="$BIN_LINK_DIR/$APP_COMMAND"
Terminal=false
Type=Application
Categories=Utility;
EOL

# Añadir icono si se seleccionó
if [ -n "$ICON_PATH" ]; then
    echo "Icon=$INSTALL_DIR/$ICON_PATH" >> "$DESKTOP_FILE_PATH"
fi

# Darle permisos de ejecución al archivo .desktop
chmod +x "$DESKTOP_FILE_PATH"


# --- 6. Confirmación Final ---
echo
success "¡Instalación completada!"
echo "--------------------------------------------------"
echo -e "Nombre: ${C_YELLOW}$APP_NAME${C_RESET}"
echo -e "Instalado en: ${C_YELLOW}$INSTALL_DIR${C_RESET}"
echo -e "Ejecútalo desde la terminal con: ${C_YELLOW}$APP_COMMAND${C_RESET}"
echo -e "O búscalo en tu menú de aplicaciones."
echo "--------------------------------------------------"

# La limpieza del directorio temporal se ejecuta automáticamente al salir.
exit 0
