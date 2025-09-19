#!/bin/bash

# ##################################################################
# Un asistente universal y consistente para instalar aplicaciones
# desde archivos .zip o .tar.gz.
# ##################################################################

VERSION_LOCAL="0.4" # Subimos la versión por la nueva funcionalidad

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

function instalar_aplicacion() {
    read -p "Arrastra el archivo (.zip o .tar.gz) a la terminal y presiona Enter: " ARCHIVE_FILE
    ARCHIVE_FILE="${ARCHIVE_FILE//\'/}"

    if [ -z "$ARCHIVE_FILE" ]; then error "No se proporcionó ninguna ruta de archivo."; fi
    if [ ! -f "$ARCHIVE_FILE" ]; then error "El archivo '$ARCHIVE_FILE' no existe."; fi
    
    TEMP_DIR=$(mktemp -d -t install-app-XXXXXX)
    trap 'info "Limpiando archivos temporales..."; rm -rf "$TEMP_DIR"' EXIT

    info "Descomprimiendo '$ARCHIVE_FILE'..."
    case "$ARCHIVE_FILE" in
        *.zip) unzip -q "$ARCHIVE_FILE" -d "$TEMP_DIR" || error "No se pudo descomprimir el archivo ZIP." ;;
        *.tar.gz|*.tgz) tar -xzf "$ARCHIVE_FILE" -C "$TEMP_DIR" || error "No se pudo descomprimir el archivo TAR.GZ." ;;
        *) error "Formato de archivo no soportado. Usa .zip o .tar.gz." ;;
    esac

    cd "$TEMP_DIR" || error "No se pudo acceder al directorio temporal."
    if [ "$(ls -1 . | wc -l)" -eq 1 ] && [ -d "$(ls -1 .)" ]; then
        info "El archivo contenía una sola carpeta, accediendo a ella."
        cd "$(ls -1 .)" || error "No se pudo acceder a la subcarpeta."
    fi

    info "Analizando el contenido de la aplicación..."
    readarray -t EXECUTABLES < <(find . -type f -executable -not -name "*.so*" 2>/dev/null)
    if [ ${#EXECUTABLES[@]} -eq 0 ]; then error "No se encontraron archivos ejecutables."; fi

    info "Selecciona el ejecutable principal:"
    PS3="Selecciona el número del ejecutable: "
    select EXEC_PATH in "${EXECUTABLES[@]}"; do
        if [[ -n "$EXEC_PATH" ]]; then break; else warn "Selección inválida."; fi
    done

    readarray -t ICONS < <(find . -type f \( -name "*.png" -o -name "*.svg" \) 2>/dev/null)
    ICON_PATH=""
    if [ ${#ICONS[@]} -gt 0 ]; then
        info "Selecciona un icono (opcional)."
        ICONS+=("No seleccionar ningún icono")
        PS3="Selecciona el número del icono: "
        select ICON_CANDIDATE in "${ICONS[@]}"; do
            if [[ -n "$ICON_CANDIDATE" && "$ICON_CANDIDATE" != "No seleccionar ningún icono" ]]; then
                ICON_PATH="$ICON_CANDIDATE"; break
            elif [[ "$ICON_CANDIDATE" == "No seleccionar ningún icono" ]]; then
                info "Se omitió la selección de icono."; break
            else warn "Selección inválida."; fi
        done
    else
        warn "No se encontraron archivos de icono."
    fi

    echo -e "\n${C_CYAN}--- Configuración de la Instalación ---${C_RESET}"
    read -p "Introduce el nombre para la aplicación (ej. Visual Studio Code): " APP_NAME
    APP_DIR_NAME=$(echo "$APP_NAME" | sed 's/ /-/g')

    info "Elige una ubicación para la instalación:"
    INSTALL_OPTIONS=("Solo para el usuario actual (~/Applications) - Recomendado" "Para todos los usuarios del sistema (/opt) - Requiere Sudo" "Especificar una ruta personalizada")
    PS3="Selecciona una opción: "
    select opt in "${INSTALL_OPTIONS[@]}"; do
        case $REPLY in
            1) INSTALL_DIR="$HOME/Applications/$APP_DIR_NAME"; BIN_LINK_DIR="$HOME/.local/bin"; DESKTOP_DIR="$HOME/.local/share/applications"; NEEDS_SUDO=false; break ;;
            2) INSTALL_DIR="/opt/$APP_DIR_NAME"; BIN_LINK_DIR="/usr/local/bin"; DESKTOP_DIR="/usr/share/applications"; NEEDS_SUDO=true; break ;;
            3) read -p "Introduce la ruta de instalación (sin el nombre de la app): " CUSTOM_PATH; INSTALL_DIR="${CUSTOM_PATH%/}/$APP_DIR_NAME"; BIN_LINK_DIR="$HOME/.local/bin"; DESKTOP_DIR="$HOME/.local/share/applications"; warn "Los enlaces se crearán para el usuario actual."; NEEDS_SUDO=false; break ;;
            *) warn "Opción inválida." ;;
        esac
    done

    info "Preparando para instalar..."
    if [ "$NEEDS_SUDO" = true ] && [ "$EUID" -ne 0 ]; then
        info "Se requieren privilegios de administrador."
        sudo bash "$0" --install_sudo_helper
        # Esta es una forma de pasar los datos a la nueva instancia de sudo
        # Es compleja, una alternativa es volver a preguntar dentro del modo sudo.
        exit $?
    fi

    mkdir -p "$INSTALL_DIR" || error "No se pudo crear el directorio de instalación: $INSTALL_DIR"
    mkdir -p "$BIN_LINK_DIR"; mkdir -p "$DESKTOP_DIR"

    info "Copiando archivos de la aplicación a '$INSTALL_DIR'..."
    rsync -a --progress . "$INSTALL_DIR/" || error "Fallo al copiar los archivos."

    APP_COMMAND_NAME=$(basename "$EXEC_PATH" | sed 's/\.sh$//')
    info "Creando comando de terminal: '$APP_COMMAND_NAME'..."
    ln -sf "$INSTALL_DIR/$EXEC_PATH" "$BIN_LINK_DIR/$APP_COMMAND_NAME"

    DESKTOP_FILE_PATH="$DESKTOP_DIR/$APP_DIR_NAME.desktop"
    info "Creando archivo de menú en '$DESKTOP_FILE_PATH'..."

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
    if [ -n "$ICON_PATH" ]; then echo "Icon=$INSTALL_DIR/$ICON_PATH" >> "$DESKTOP_FILE_PATH"; fi
    chmod +x "$DESKTOP_FILE_PATH"

    # --- Confirmación y Registro (UBICACIÓN CORREGIDA) ---
    echo
    success "¡Instalación completada!"
    
    info "Guardando información en el registro..."
    local REGISTRY_FILE="$HOME/.config/app-installer/registry.log"
    mkdir -p "$(dirname "$REGISTRY_FILE")"
    echo "$APP_NAME|$INSTALL_DIR|$BIN_LINK_DIR/$APP_COMMAND_NAME|$DESKTOP_FILE_PATH" >> "$REGISTRY_FILE"
    
    echo "--------------------------------------------------"
    echo -e " Aplicación:    ${C_YELLOW}$APP_NAME${C_RESET}"
    echo -e " Instalado en:    ${C_YELLOW}$INSTALL_DIR${C_RESET}"
    echo -e " Comando:         ${C_YELLOW}$APP_COMMAND_NAME${C_RESET}"
    echo "--------------------------------------------------"
}

function desinstalar_aplicacion() {
    local REGISTRY_FILE="$HOME/.config/app-installer/registry.log"
    if [ ! -f "$REGISTRY_FILE" ] || [ ! -s "$REGISTRY_FILE" ]; then
        error "No se encontró el registro o está vacío. No hay aplicaciones para desinstalar."
        return 1
    fi

    info "Selecciona la aplicación que deseas desinstalar:"
    mapfile -t installed_apps < "$REGISTRY_FILE"
    installed_apps+=("Cancelar")

    PS3="Selecciona el número de la aplicación a borrar: "
    select app_line in "${installed_apps[@]}"; do
        if [[ "$app_line" == "Cancelar" ]]; then info "Operación cancelada."; return 0; fi
        if [[ -n "$app_line" ]]; then break; else warn "Selección inválida."; fi
    done

    local APP_TO_UNINSTALL=$(echo "$app_line" | cut -d'|' -f1)
    local DIR_TO_UNINSTALL=$(echo "$app_line" | cut -d'|' -f2)
    local LINK_TO_UNINSTALL=$(echo "$app_line" | cut -d'|' -f3)
    local DESKTOP_TO_UNINSTALL=$(echo "$app_line" | cut -d'|' -f4)

    echo
    warn "Estás a punto de eliminar permanentemente lo siguiente:"
    echo -e "  - Aplicación:    ${C_YELLOW}$APP_TO_UNINSTALL${C_RESET}"
    echo -e "  - Directorio:    ${C_YELLOW}$DIR_TO_UNINSTALL${C_RESET}"
    echo -e "  - Comando:         ${C_YELLOW}$LINK_TO_UNINSTALL${C_RESET}"
    echo -e "  - Acceso Directo:  ${C_YELLOW}$DESKTOP_TO_UNINSTALL${C_RESET}"
    read -p "¿Estás seguro? Esta acción no se puede deshacer. [s/N]: " confirmation

    if [[ "$confirmation" != "s" && "$confirmation" != "S" ]]; then
        info "Desinstalación cancelada por el usuario."; return 0;
    fi

    local SUDO_CMD=""
    if [[ "$DIR_TO_UNINSTALL" == /opt/* || "$LINK_TO_UNINSTALL" == /usr/* || "$DESKTOP_TO_UNINSTALL" == /usr/* ]]; then
        info "Se requieren privilegios de administrador para desinstalar esta aplicación."
        SUDO_CMD="sudo"
    fi
    
    info "Eliminando directorio de la aplicación..."; $SUDO_CMD rm -rf "$DIR_TO_UNINSTALL"
    info "Eliminando comando de la terminal..."; $SUDO_CMD rm -f "$LINK_TO_UNINSTALL"
    info "Eliminando acceso directo del menú..."; $SUDO_CMD rm -f "$DESKTOP_TO_UNINSTALL"
    
    info "Actualizando el registro..."
    grep -vF "$app_line" "$REGISTRY_FILE" > "${REGISTRY_FILE}.tmp"
    mv "${REGISTRY_FILE}.tmp" "$REGISTRY_FILE"

    echo
    success "¡'$APP_TO_UNINSTALL' ha sido desinstalada correctamente!"
}

function actualizar_script() {
    echo -e "\n${C_YELLOW}› Verificando actualizaciones para el script...${C_RESET}"
    local repos_posibles=("Application-Installer-in-ZIP"); local scripts_posibles=("instalar-app.sh")
    local url_version_encontrada=""; local url_script_encontrado=""; local exito=false; local download_tool=""
    if command -v curl &> /dev/null; then download_tool="curl -sfo"; elif command -v wget &> /dev/null; then download_tool="wget -qO"; else
        error "Se necesita 'curl' o 'wget' para la auto-actualización."
    fi
    for repo in "${repos_posibles[@]}"; do
        local url_temp_version="https://raw.githubusercontent.com/RichyKunBv/${repo}/main/version.txt"
        if curl --output /dev/null --silent --head --fail "$url_temp_version"; then
            url_version_encontrada="$url_temp_version"
            for script_name in "${scripts_posibles[@]}"; do
                local url_temp_script="https://raw.githubusercontent.com/RichyKunBv/${repo}/main/${script_name}"
                if curl --output /dev/null --silent --head --fail "$url_temp_script"; then
                    url_script_encontrado="$url_temp_script"; exito=true; break
                fi; done; fi; [ "$exito" = true ] && break; done
    if [ "$exito" = false ]; then error "No se pudo encontrar un repositorio o script válido en GitHub."; fi
    local version_remota; version_remota=$($download_tool - "$url_version_encontrada")
    if [ -z "$version_remota" ]; then error "No se pudo obtener la versión remota."; fi
    if dpkg --compare-versions "$version_remota" gt "$VERSION_LOCAL"; then
        echo -e "${C_GREEN}  ¡Nueva versión ($version_remota) encontrada! La tuya es la $VERSION_LOCAL.${C_RESET}"
        echo -e "${C_YELLOW}  Descargando actualización...${C_RESET}"
        local script_actual="$0"; local script_nuevo="${script_actual}.new"
        if $download_tool "$script_nuevo" "$url_script_encontrado"; then
            chmod +x "$script_nuevo"; mv "$script_nuevo" "$script_actual"
            success "¡Script actualizado con éxito!"; echo -e "${C_YELLOW}  Vuelve a ejecutar el script.${C_RESET}"; exit 0
        else error "Error al descargar el script actualizado."; rm -f "$script_nuevo"; fi
    else success "Ya tienes la última versión ($VERSION_LOCAL)."; fi
}

#--- Menú Principal ---
while true; do
    clear 
    echo -e "${C_CYAN}===== Gestor de Aplicaciones =====${C_RESET}"
    echo "Version: $VERSION_LOCAL"
    echo "1. Instalar aplicación desde archivo"
    echo "2. Desinstalar aplicacion (solo las instaladas desde este Script)"
    echo "Y. Actualizar script"
    echo "X. Salir"
    echo "---------------------------------------"
    read -p "Selecciona una opción: " opcion

    case $opcion in
        1)
            instalar_aplicacion
            read -p "Presiona Enter para volver al menú..."
            ;;
        2)
            desinstalar_aplicacion
            read -p "Presiona Enter para volver al menú..."
            ;;
        [yY])
            actualizar_script
            read -p "Presiona Enter para volver al menú..."
            ;;
        [xX])
            echo "Saliendo..."
            exit 0
            ;;
        *)
            warn "Opción no válida. Inténtalo de nuevo."
            sleep 2 
            ;;
    esac
done