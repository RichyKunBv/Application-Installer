#!/bin/bash

# ##################################################################
# Gestor de Aplicaciones v1.0
# Instala, desinstala y gestiona aplicaciones desde archivos
# comprimidos (.zip, .tar.gz, .tar.xz, .tar.bz2, .7z) y binarios.
# ##################################################################

VERSION_LOCAL="1.0.2"

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
    read -p "Arrastra un archivo (.zip, .tar.*, .7z o binario) y presiona Enter: " INPUT_FILE
    INPUT_FILE="${INPUT_FILE//\'/}"

    if [ -z "$INPUT_FILE" ]; then error "No se proporcionó ninguna ruta."; fi
    if [ ! -e "$INPUT_FILE" ]; then error "El archivo o directorio '$INPUT_FILE' no existe."; fi

    TEMP_DIR=$(mktemp -d -t install-app-XXXXXX)
    trap 'info "Limpiando archivos temporales..."; rm -rf "$TEMP_DIR"' EXIT
    
    # VERSIÓN 1.0: Manejo de binarios simples
    if [ -f "$INPUT_FILE" ] && [ -x "$INPUT_FILE" ] && ! [[ "$INPUT_FILE" =~ \.zip$|\.tar\..*$|\.tgz$|\.7z$ ]]; then
        info "Se detectó un archivo binario simple."
        cp "$INPUT_FILE" "$TEMP_DIR/"
        EXEC_PATH="./$(basename "$INPUT_FILE")"
    else # Proceso para archivos comprimidos
        info "Descomprimiendo '$INPUT_FILE'..."
        case "$INPUT_FILE" in
            *.zip) unzip -q "$INPUT_FILE" -d "$TEMP_DIR" || error "Fallo al descomprimir ZIP." ;;
            *.tar.gz|*.tgz) tar -xzf "$INPUT_FILE" -C "$TEMP_DIR" || error "Fallo al descomprimir TAR.GZ." ;;
            *.tar.xz) tar -xf "$INPUT_FILE" -C "$TEMP_DIR" || error "Fallo al descomprimir TAR.XZ." ;;
            *.tar.bz2|*.tbz2) tar -xjf "$INPUT_FILE" -C "$TEMP_DIR" || error "Fallo al descomprimir TAR.BZ2." ;;
            *.7z)
                if ! command -v 7z &>/dev/null; then error "Se necesita 'p7zip-full' para extraer .7z."; fi
                7z x "$INPUT_FILE" -o"$TEMP_DIR" >/dev/null || error "Fallo al descomprimir 7Z." ;;
            *) error "Formato de archivo no soportado." ;;
        esac

        cd "$TEMP_DIR" || error "No se pudo acceder al directorio temporal."
        if [ "$(ls -1 . | wc -l)" -eq 1 ] && [ -d "$(ls -1 .)" ]; then
            info "El archivo contenía una sola carpeta, accediendo a ella."
            cd "$(ls -1 .)" || error "No se pudo acceder a la subcarpeta."
        fi

        info "Analizando el contenido de la aplicación..."
        # VERSIÓN 1.0: Búsqueda inteligente de ejecutables
        readarray -t EXECUTABLES < <(find . -maxdepth 2 -type f -executable -not -name "*.so*" | grep -viE 'uninstall|setup|update|crashpad' ; find . -type f -executable -not -name "*.so*")
        
        if [ ${#EXECUTABLES[@]} -eq 0 ]; then error "No se encontraron archivos ejecutables."; fi
        # Eliminar duplicados si la búsqueda ampliada encuentra los mismos
        mapfile -t EXECUTABLES < <(printf "%s\n" "${EXECUTABLES[@]}" | sort -u)

        info "Selecciona el ejecutable principal (se muestran los más probables primero):"
        PS3="Selecciona el número del ejecutable: "
        select EXEC_PATH in "${EXECUTABLES[@]}"; do
            if [[ -n "$EXEC_PATH" ]]; then break; else warn "Selección inválida."; fi
        done
    fi

    # VERSIÓN 1.0: Detección de dependencias
    info "Analizando dependencias del ejecutable..."
    if command -v ldd &>/dev/null; then
        MISSING_LIBS=$(ldd "$EXEC_PATH" 2>/dev/null | grep 'not found')
        if [ -n "$MISSING_LIBS" ]; then
            warn "La aplicación podría necesitar las siguientes librerías que no se encontraron:"
            echo -e "${C_YELLOW}$MISSING_LIBS${C_RESET}"
            read -p "Asegúrate de instalarlas con tu gestor de paquetes. ¿Deseas continuar con la instalación de todas formas? [S/n]: " continue_anyway
            if [[ "$continue_anyway" == "n" || "$continue_anyway" == "N" ]]; then
                error "Instalación cancelada por el usuario."
            fi
        else
            success "No se detectaron dependencias faltantes."
        fi
    else
        warn "No se encontró el comando 'ldd'. Omitiendo la verificación de dependencias."
    fi

    ICON_PATH=""
    if [ ! -f "$EXEC_PATH" ]; then # Si es un binario simple, no buscamos icono
        # VERSIÓN 1.0: Búsqueda inteligente de iconos
        readarray -t ICONS < <(find . -type f \( -ipath "*scalable*" -o -ipath "*256x256*" -o -ipath "*512x512*" -o -ipath "*icons/hicolor*" \) 2>/dev/null ; find . -type f \( -name "*.png" -o -name "*.svg" \) 2>/dev/null)
        if [ ${#ICONS[@]} -gt 0 ]; then
            mapfile -t ICONS < <(printf "%s\n" "${ICONS[@]}" | sort -u)
            info "Selecciona un icono (opcional, se muestran los de alta resolución primero):"
            ICONS+=("No seleccionar ningún icono")
            PS3="Selecciona el número del icono: "
            select ICON_CANDIDATE in "${ICONS[@]}"; do
                if [[ -n "$ICON_CANDIDATE" && "$ICON_CANDIDATE" != "No seleccionar ningún icono" ]]; then
                    ICON_PATH="$ICON_CANDIDATE"; break
                elif [[ "$ICON_CANDIDATE" == "No seleccionar ningún icono" ]]; then
                    info "Se omitió la selección de icono."; break
                else warn "Selección inválida."; fi
            done
        else warn "No se encontraron archivos de icono."; fi
    fi

    echo -e "\n${C_CYAN}--- Configuración de la Instalación ---${C_RESET}"
    read -p "Introduce el nombre para la aplicación: " APP_NAME

    # VERSIÓN 1.0: Aviso de instalación duplicada
    local REGISTRY_FILE="$HOME/.config/app-installer/registry.log"
    if [ -f "$REGISTRY_FILE" ] && grep -q "^${APP_NAME}|" "$REGISTRY_FILE"; then
        warn "Ya existe una aplicación registrada con el nombre '$APP_NAME'."
        read -p "¿Deseas continuar? Podrías sobreescribirla o crear un duplicado. [s/N]: " continue_duplicate
        if [[ "$continue_duplicate" != "s" && "$continue_duplicate" != "S" ]]; then
            error "Instalación cancelada por el usuario.";
        fi
    fi

    APP_DIR_NAME=$(echo "$APP_NAME" | sed 's/ /-/g')
    # ... (resto de la función de instalación sin cambios)
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
    # ... (sudo, mkdir, rsync, ln, .desktop, registro, etc., sin cambios)
    if [ "$NEEDS_SUDO" = true ] && [ "$EUID" -ne 0 ]; then info "Se requieren privilegios de administrador."; sudo bash "$0"; exit $?; fi
    mkdir -p "$INSTALL_DIR" || error "No se pudo crear el directorio de instalación."
    mkdir -p "$BIN_LINK_DIR"; mkdir -p "$DESKTOP_DIR"
    info "Copiando archivos de la aplicación a '$INSTALL_DIR'..."
    if [ -f "$EXEC_PATH" ]; then
        rsync -a --progress . "$INSTALL_DIR/" || error "Fallo al copiar los archivos."
    else
        cp "$EXEC_PATH" "$INSTALL_DIR/" || error "Fallo al copiar el binario."
    fi
    APP_COMMAND_NAME=$(basename "$EXEC_PATH" | sed 's/\.sh$//')
    info "Creando comando de terminal: '$APP_COMMAND_NAME'..."
    ln -sf "$INSTALL_DIR/$(basename $EXEC_PATH)" "$BIN_LINK_DIR/$APP_COMMAND_NAME"
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
    success "¡Instalación completada!"
    info "Guardando información en el registro..."
    mkdir -p "$(dirname "$REGISTRY_FILE")"
    echo "$APP_NAME|$INSTALL_DIR|$BIN_LINK_DIR/$APP_COMMAND_NAME|$DESKTOP_FILE_PATH" >> "$REGISTRY_FILE"
    echo "--------------------------------------------------"; echo -e " Aplicación:    ${C_YELLOW}$APP_NAME${C_RESET}"; echo -e " Instalado en:    ${C_YELLOW}$INSTALL_DIR${C_RESET}"; echo -e " Comando:         ${C_YELLOW}$APP_COMMAND_NAME${C_RESET}"; echo "--------------------------------------------------";
}

function desinstalar_aplicacion() {
    # VERSIÓN 0.5: Añadida
    local REGISTRY_FILE="$HOME/.config/app-installer/registry.log"
    # ... (código de desinstalación sin cambios)
    if [ ! -f "$REGISTRY_FILE" ] || [ ! -s "$REGISTRY_FILE" ]; then error "No se encontró el registro o está vacío."; return 1; fi
    info "Selecciona la aplicación que deseas desinstalar:"; mapfile -t installed_apps < "$REGISTRY_FILE"; installed_apps+=("Cancelar"); PS3="Selecciona el número de la aplicación a borrar: ";
    select app_line in "${installed_apps[@]}"; do
        if [[ "$app_line" == "Cancelar" ]]; then info "Operación cancelada."; return 0; fi
        if [[ -n "$app_line" ]]; then break; else warn "Selección inválida."; fi
    done
    local APP_TO_UNINSTALL=$(echo "$app_line" | cut -d'|' -f1); local DIR_TO_UNINSTALL=$(echo "$app_line" | cut -d'|' -f2); local LINK_TO_UNINSTALL=$(echo "$app_line" | cut -d'|' -f3); local DESKTOP_TO_UNINSTALL=$(echo "$app_line" | cut -d'|' -f4);
    local APP_COMMAND_NAME=$(basename "$LINK_TO_UNINSTALL"); info "Verificando si '${APP_TO_UNINSTALL}' está en ejecución..."; PIDS=$(pgrep -f "$APP_COMMAND_NAME");
    if [ -n "$PIDS" ]; then
        warn "La aplicación '${APP_TO_UNINSTALL}' parece estar en ejecución (PIDs: $PIDS)."; read -p "¿Deseas forzar el cierre de todos sus procesos? [s/N]: " force_close
        if [[ "$force_close" == "s" || "$force_close" == "S" ]]; then info "Cerrando procesos..."; kill -9 $PIDS; success "Procesos cerrados."; sleep 1; else error "Desinstalación cancelada."; return 1; fi
    else success "La aplicación no está en ejecución."; fi
    echo; warn "Estás a punto de eliminar permanentemente lo siguiente:"; echo -e "  - Aplicación:    ${C_YELLOW}$APP_TO_UNINSTALL${C_RESET}"; echo -e "  - Directorio:    ${C_YELLOW}$DIR_TO_UNINSTALL${C_RESET}"; echo -e "  - Comando:         ${C_YELLOW}$LINK_TO_UNINSTALL${C_RESET}"; echo -e "  - Acceso Directo:  ${C_YELLOW}$DESKTOP_TO_UNINSTALL${C_RESET}"; read -p "¿Estás seguro? [s/N]: " confirmation
    if [[ "$confirmation" != "s" && "$confirmation" != "S" ]]; then info "Desinstalación cancelada."; return 0; fi
    local SUDO_CMD=""; if [[ "$DIR_TO_UNINSTALL" == /opt/* || "$LINK_TO_UNINSTALL" == /usr/* || "$DESKTOP_TO_UNINSTALL" == /usr/* ]]; then info "Se requieren privilegios de administrador."; SUDO_CMD="sudo"; fi
    info "Eliminando directorio..."; $SUDO_CMD rm -rf "$DIR_TO_UNINSTALL"; info "Eliminando comando..."; $SUDO_CMD rm -f "$LINK_TO_UNINSTALL"; info "Eliminando acceso directo..."; $SUDO_CMD rm -f "$DESKTOP_TO_UNINSTALL"; info "Actualizando el registro..."; grep -vF "$app_line" "$REGISTRY_FILE" > "${REGISTRY_FILE}.tmp"; mv "${REGISTRY_FILE}.tmp" "$REGISTRY_FILE"; echo; success "¡'$APP_TO_UNINSTALL' ha sido desinstalada!";
}

function listar_aplicaciones() {
    # VERSIÓN 0.6: Añadida
    local REGISTRY_FILE="$HOME/.config/app-installer/registry.log"
    # ... (código de listar sin cambios)
    if [ ! -f "$REGISTRY_FILE" ] || [ ! -s "$REGISTRY_FILE" ]; then error "No se encontró el registro o está vacío."; return 1; fi
    echo -e "\n${C_CYAN}--- Aplicaciones Instaladas ---${C_RESET}"; echo "---------------------------------------------------------------------"; printf "%-25s | %-20s | %s\n" "NOMBRE" "COMANDO" "RUTA DE INSTALACIÓN"; echo "---------------------------------------------------------------------";
    while IFS='|' read -r name dir command desktop_file; do
        printf "%-25s | %-20s | %s\n" "$name" "$(basename $command)" "$dir"
    done < "$REGISTRY_FILE"; echo "---------------------------------------------------------------------";
}

function actualizar_script() {
    # CORRECCIÓN: Usar las variables de color correctas (C_*)
    echo -e "\n${C_YELLOW}› Verificando actualizaciones para el script...${C_RESET}"
    
    # CORRECCIÓN: Nombre del repositorio corregido
    local repos_posibles=("Application-Installer-in-ZIP")
    local scripts_posibles=("instalar-app.sh")

    local url_version_encontrada=""
    local url_script_encontrado=""
    local exito=false
    local download_tool=""

    if command -v curl &> /dev/null; then
        download_tool="curl -sfo"
    elif command -v wget &> /dev/null; then
        download_tool="wget -qO"
    else
        error "Se necesita 'curl' o 'wget' para la auto-actualización."
        return 1
    fi

    # Bucle para encontrar la URL válida (sin cambios en la lógica)
    for repo in "${repos_posibles[@]}"; do
        local url_temp_version="https://raw.githubusercontent.com/RichyKunBv/${repo}/main/version.txt"
        if curl --output /dev/null --silent --head --fail "$url_temp_version"; then
            url_version_encontrada="$url_temp_version"
            for script_name in "${scripts_posibles[@]}"; do
                local url_temp_script="https://raw.githubusercontent.com/RichyKunBv/${repo}/main/${script_name}"
                if curl --output /dev/null --silent --head --fail "$url_temp_script"; then
                    url_script_encontrado="$url_temp_script"
                    exito=true
                    break
                fi
            done
        fi
        [ "$exito" = true ] && break
    done

    if [ "$exito" = false ]; then
        error "No se pudo encontrar un repositorio o script válido en GitHub."
        return 1
    fi

    local version_remota
    version_remota=$($download_tool - "$url_version_encontrada" | tr -d '[:space:]') # tr -d elimina espacios/líneas en blanco
    if [ -z "$version_remota" ]; then
        error "No se pudo obtener la versión remota."
        return 1
    fi
    
    # CORRECCIÓN: Reemplazo de dpkg por un método universal
    local version_mas_nueva=$(printf "%s\n%s" "$version_remota" "$VERSION_LOCAL" | sort -V | tail -n1)
    
    if [[ "$version_mas_nueva" != "$VERSION_LOCAL" ]]; then
        echo -e "${C_GREEN}  ¡Nueva versión ($version_remota) encontrada! La tuya es la $VERSION_LOCAL.${C_RESET}"
        echo -e "${C_YELLOW}  Descargando actualización...${C_RESET}"
        
        local script_actual="$0"
        local script_nuevo="${script_actual}.new"
        
        if $download_tool "$script_nuevo" "$url_script_encontrado"; then
            chmod +x "$script_nuevo"
            mv "$script_nuevo" "$script_actual"
            success "¡Script actualizado con éxito!"
            echo -e "${C_YELLOW}  Por favor, vuelve a ejecutar el script para usar la nueva versión.${C_RESET}"
            exit 0
        else
            error "Error al descargar el script actualizado."
            rm -f "$script_nuevo"
            return 1
        fi
    else
        success "Ya tienes la última versión ($VERSION_LOCAL). No se necesita actualizar."
    fi
}

#--- Menú Principal ---
while true; do
    clear 
    echo -e "${C_CYAN}===== Gestor de Aplicaciones v$VERSION_LOCAL =====${C_RESET}"
    echo "1. Instalar aplicación"
    echo "2. Desinstalar aplicación"
    echo "3. Listar aplicaciones instaladas"
    echo "Y. Actualizar script"
    echo "X. Salir"
    echo "---------------------------------------"
    read -p "Selecciona una opción: " opcion

    case $opcion in
        1) instalar_aplicacion; read -p "Presiona Enter para volver al menú...";;
        2) desinstalar_aplicacion; read -p "Presiona Enter para volver al menú...";;
        3) listar_aplicaciones; read -p "Presiona Enter para volver al menú...";;
        [yY]) actualizar_script; read -p "Presiona Enter para volver al menú...";;
        [xX]) echo "Saliendo..."; exit 0;;
        *) warn "Opción no válida."; sleep 2;;
    esac
done
