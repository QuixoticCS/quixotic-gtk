#! /usr/bin/env bash

set -Eeo pipefail

REPO_DIR="$(git rev-parse --show-toplevel)"
SRC_DIR="${REPO_DIR}/src"

ROOT_UID=0
DEST_DIR=

ctype=

# Destination directory
if [ "$UID" -eq "$ROOT_UID" ]; then
    DEST_DIR="/usr/share/themes"
else
    DEST_DIR="$HOME/.themes"
fi

SASSC_OPT="-M -t expanded"

THEME_NAME=Quixotic
THEME_VARIANTS=('' '-red' '-green' '-pink' '-purple' '-cyan')
COLOR_VARIANTS=('' '-light' '-dark')
SIZE_VARIANTS=('' '-compact')

if [[ "$(command -v gnome-shell)" ]]; then
    SHELL_VERSION="$(gnome-shell --version | cut -d ' ' -f 3 | cut -d . -f -1)"
    if [[ "${SHELL_VERSION:-}" -ge "40" ]]; then
        GS_VERSION="new"
    else
        GS_VERSION="old"
    fi
else
    echo "'gnome-shell' not found, using styles for last gnome-shell version available."
    GS_VERSION="new"
fi

usage() {
    cat <<EOF
Usage: $0 [OPTION]...

OPTIONS:
  -d, --dest DIR          Specify destination directory (Default: $DEST_DIR)

  -n, --name NAME         Specify theme name (Default: $THEME_NAME)

  -t, --theme VARIANT     Specify theme color variant(s) [default|red|green|pink|purple|cyan|all] (Default: blue)

  -c, --color VARIANT     Specify color variant(s) [standard|light|dark] (Default: All variants)s)

  -s, --size VARIANT      Specify size variant [standard|compact] (Default: standard variants)

  --tweaks                Specify versions for tweaks [nord|black|rimless] (nord can not mix use with black !)
                          1. nord:     Nord color version
                          2. black:    Blackness color version
                          3. rimless:  Remove the 1px border about windows and menus

  -h, --help              Show help
EOF
}

install() {
    local dest="${1}"
    local name="${2}"
    local theme="${3}"
    local color="${4}"
    local size="${5}"
    local ctype="${6}"

    [[ "${color}" == '-light' ]] && local ELSE_LIGHT="${color}"
    [[ "${color}" == '-dark' ]] && local ELSE_DARK="${color}"

    local THEME_DIR="${1}/${2}${3}${4}${5}${6}"

    [[ -d "${THEME_DIR}" ]] && rm -rf "${THEME_DIR}"

    echo "Installing '${THEME_DIR}'..."

    theme_tweaks

    mkdir -p "${THEME_DIR}"

    echo "[Desktop Entry]" >>"${THEME_DIR}/index.theme"
    echo "Type=X-GNOME-Metatheme" >>"${THEME_DIR}/index.theme"
    echo "Name=${2}${3}${4}${5}${6}" >>"${THEME_DIR}/index.theme"
    echo "Comment=An Flat Gtk+ theme based on Elegant Design" >>"${THEME_DIR}/index.theme"
    echo "Encoding=UTF-8" >>"${THEME_DIR}/index.theme"
    echo "" >>"${THEME_DIR}/index.theme"
    echo "[X-GNOME-Metatheme]" >>"${THEME_DIR}/index.theme"
    echo "GtkTheme=${2}${3}${4}${5}${6}" >>"${THEME_DIR}/index.theme"
    echo "MetacityTheme=${2}${3}${4}${5}${6}" >>"${THEME_DIR}/index.theme"
    echo "IconTheme=Tela-circle${ELSE_DARK:-}" >>"${THEME_DIR}/index.theme"
    echo "CursorTheme=${2}-cursors" >>"${THEME_DIR}/index.theme"
    echo "ButtonLayout=close,minimize,maximize:menu" >>"${THEME_DIR}/index.theme"

    mkdir -p "${THEME_DIR}/gnome-shell"
    cp -r "${SRC_DIR}/main/gnome-shell/pad-osd.css" "${THEME_DIR}/gnome-shell"

    if [[ "$tweaks" == 'true' ]]; then
        if [[ "${GS_VERSION:-}" == 'new' ]]; then
            sassc $SASSC_OPT "${SRC_DIR}/main/gnome-shell/shell-40-0/gnome-shell${color}.scss" "${THEME_DIR}/gnome-shell/gnome-shell.css"
        else
            sassc $SASSC_OPT "${SRC_DIR}/main/gnome-shell/shell-3-28/gnome-shell${color}.scss" "${THEME_DIR}/gnome-shell/gnome-shell.css"
        fi
    else
        if [[ "${GS_VERSION:-}" == 'new' ]]; then
            cp -r "${SRC_DIR}/main/gnome-shell/shell-40-0/gnome-shell${color}.css" "${THEME_DIR}/gnome-shell/gnome-shell.css"
        else
            cp -r "${SRC_DIR}/main/gnome-shell/shell-3-28/gnome-shell${color}.css" "${THEME_DIR}/gnome-shell/gnome-shell.css"
        fi
    fi

    cp -r "${SRC_DIR}/assets/gnome-shell/common-assets" "${THEME_DIR}/gnome-shell/assets"
    cp -r "${SRC_DIR}/assets/gnome-shell/assets${ELSE_DARK:-}/"*.svg "${THEME_DIR}/gnome-shell/assets"
    cp -r "${SRC_DIR}/assets/gnome-shell/theme${theme}/"*.svg "${THEME_DIR}/gnome-shell/assets"

    cd "${THEME_DIR}/gnome-shell"
    ln -s assets/no-events.svg no-events.svg
    ln -s assets/process-working.svg process-working.svg
    ln -s assets/no-notifications.svg no-notifications.svg

    mkdir -p "${THEME_DIR}/gtk-2.0"
    cp -r "${SRC_DIR}/main/gtk-2.0/gtkrc${theme}${ELSE_DARK:-}" "${THEME_DIR}/gtk-2.0/gtkrc"
    cp -r "${SRC_DIR}/main/gtk-2.0/common/"*'.rc' "${THEME_DIR}/gtk-2.0"
    cp -r "${SRC_DIR}/assets/gtk-2.0/assets${theme}${ELSE_DARK:-}" "${THEME_DIR}/gtk-2.0/assets"

    mkdir -p "${THEME_DIR}/gtk-3.0"
    cp -r "${SRC_DIR}/assets/gtk/assets${theme}${ctype}" "${THEME_DIR}/gtk-3.0/assets"
    cp -r "${SRC_DIR}/assets/gtk/scalable" "${THEME_DIR}/gtk-3.0/assets"
    cp -r "${SRC_DIR}/assets/gtk/thumbnail${ELSE_DARK:-}.png" "${THEME_DIR}/gtk-3.0/thumbnail.png"

    if [[ "$tweaks" == 'true' ]]; then
        sassc $SASSC_OPT "${SRC_DIR}/main/gtk-3.0/gtk${color}.scss" "${THEME_DIR}/gtk-3.0/gtk.css"
        sassc $SASSC_OPT "${SRC_DIR}/main/gtk-3.0/gtk-dark.scss" "${THEME_DIR}/gtk-3.0/gtk-dark.css"
    else
        cp -r "${SRC_DIR}/main/gtk-3.0/gtk${color}.css" "${THEME_DIR}/gtk-3.0/gtk.css"
        cp -r "${SRC_DIR}/main/gtk-3.0/gtk-dark.css" "${THEME_DIR}/gtk-3.0"
    fi

    mkdir -p "${THEME_DIR}/gtk-4.0"
    cp -r "${SRC_DIR}/assets/gtk/assets${theme}${ctype}" "${THEME_DIR}/gtk-4.0/assets"
    cp -r "${SRC_DIR}/assets/gtk/scalable" "${THEME_DIR}/gtk-4.0/assets"
    cp -r "${SRC_DIR}/assets/gtk/thumbnail${ELSE_DARK:-}.png" "${THEME_DIR}/gtk-4.0/thumbnail.png"

    if [[ "$tweaks" == 'true' ]]; then
        sassc $SASSC_OPT "${SRC_DIR}/main/gtk-4.0/gtk${color}.scss" "${THEME_DIR}/gtk-4.0/gtk.css"
        sassc $SASSC_OPT "${SRC_DIR}/main/gtk-4.0/gtk-dark.scss" "${THEME_DIR}/gtk-4.0/gtk-dark.css"
    else
        cp -r "${SRC_DIR}/main/gtk-4.0/gtk${color}.css" "${THEME_DIR}/gtk-4.0/gtk.css"
        cp -r "${SRC_DIR}/main/gtk-4.0/gtk-dark.css" "${THEME_DIR}/gtk-4.0"
    fi

    mkdir -p "${THEME_DIR}/cinnamon"
    cp -r "${SRC_DIR}/assets/cinnamon/common-assets" "${THEME_DIR}/cinnamon/assets"
    cp -r "${SRC_DIR}/assets/cinnamon/assets${ELSE_DARK:-}/"*'.svg' "${THEME_DIR}/cinnamon/assets"
    cp -r "${SRC_DIR}/assets/cinnamon/theme${theme}/"*'.svg' "${THEME_DIR}/cinnamon/assets"

    if [[ "$tweaks" == 'true' ]]; then
        sassc $SASSC_OPT "${SRC_DIR}/main/cinnamon/cinnamon${color}.scss" "${THEME_DIR}/cinnamon/cinnamon.css"
    else
        cp -r "${SRC_DIR}/main/cinnamon/cinnamon${color}.css" "${THEME_DIR}/cinnamon/cinnamon.css"
    fi

    cp -r "${SRC_DIR}/assets/cinnamon/thumbnail${color}.png" "${THEME_DIR}/cinnamon/thumbnail.png"

    mkdir -p "${THEME_DIR}/metacity-1"
    cp -r "${SRC_DIR}/main/metacity-1/metacity-theme-2${color}.xml" "${THEME_DIR}/metacity-1/metacity-theme-2.xml"
    cp -r "${SRC_DIR}/main/metacity-1/metacity-theme-3.xml" "${THEME_DIR}/metacity-1"
    cp -r "${SRC_DIR}/assets/metacity-1/assets" "${THEME_DIR}/metacity-1"
    cp -r "${SRC_DIR}/assets/metacity-1/thumbnail${ELSE_DARK:-}.png" "${THEME_DIR}/metacity-1/thumbnail.png"
    cd "${THEME_DIR}/metacity-1" && ln -s metacity-theme-2.xml metacity-theme-1.xml

    mkdir -p "${THEME_DIR}/xfwm4"
    cp -r "${SRC_DIR}/assets/xfwm4/assets${ELSE_LIGHT:-}${ctype}/"*.png "${THEME_DIR}/xfwm4"
    cp -r "${SRC_DIR}/main/xfwm4/themerc${ELSE_LIGHT:-}" "${THEME_DIR}/xfwm4/themerc"
    mkdir -p "${THEME_DIR}-hdpi/xfwm4"
    cp -r "${SRC_DIR}/assets/xfwm4/assets${ELSE_LIGHT:-}${ctype}-hdpi/"*.png "${THEME_DIR}-hdpi/xfwm4"
    cp -r "${SRC_DIR}/main/xfwm4/themerc${ELSE_LIGHT:-}" "${THEME_DIR}-hdpi/xfwm4/themerc"
    mkdir -p "${THEME_DIR}-xhdpi/xfwm4"
    cp -r "${SRC_DIR}/assets/xfwm4/assets${ELSE_LIGHT:-}${ctype}-xhdpi/"*.png "${THEME_DIR}-xhdpi/xfwm4"
    cp -r "${SRC_DIR}/main/xfwm4/themerc${ELSE_LIGHT:-}" "${THEME_DIR}-xhdpi/xfwm4/themerc"

    mkdir -p "${THEME_DIR}/plank"
    if [[ "$color" == '-light' ]]; then
        cp -r "${SRC_DIR}/main/plank/theme-light/"* "${THEME_DIR}/plank"
    else
        cp -r "${SRC_DIR}/main/plank/theme-dark/"* "${THEME_DIR}/plank"
    fi
}

themes=()
colors=()
sizes=()

while [[ $# -gt 0 ]]; do
    case "${1}" in
    -d | --dest)
        dest="${2}"
        if [[ ! -d "${dest}" ]]; then
            echo "Destination directory does not exist. Let's make a new one..."
            mkdir -p ${dest}
        fi
        shift 2
        ;;
    -n | --name)
        name="${2}"
        shift 2
        ;;
    -c | --color)
        shift
        for color in "${@}"; do
            case "${color}" in
            standard)
                colors+=("${COLOR_VARIANTS[0]}")
                shift
                ;;
            light)
                colors+=("${COLOR_VARIANTS[1]}")
                shift
                ;;
            dark)
                colors+=("${COLOR_VARIANTS[2]}")
                shift
                ;;
            -* | --*)
                break
                ;;
            *)
                echo "ERROR: Unrecognized color variant '$1'."
                echo "Try '$0 --help' for more information."
                exit 1
                ;;
            esac
        done
        ;;
    -t | --theme)
        accent='true'
        shift
        for variant in "$@"; do
            case "$variant" in
            default)
                themes+=("${THEME_VARIANTS[0]}")
                shift
                ;;
            red)
                themes+=("${THEME_VARIANTS[1]}")
                shift
                ;;
            green)
                themes+=("${THEME_VARIANTS[2]}")
                shift
                ;;
            pink)
                themes+=("${THEME_VARIANTS[3]}")
                shift
                ;;
            purple)
                themes+=("${THEME_VARIANTS[4]}")
                shift
                ;;
            cyan)
                themes+=("${THEME_VARIANTS[5]}")
                shift
                ;;
            all)
                themes+=("${THEME_VARIANTS[@]}")
                shift
                ;;
            -*)
                break
                ;;
            *)
                echo "ERROR: Unrecognized theme variant '$1'."
                echo "Try '$0 --help' for more information."
                exit 1
                ;;
            esac
        done
        ;;
    -s | --size)
        shift
        for variant in "$@"; do
            case "$variant" in
            standard)
                sizes+=("${SIZE_VARIANTS[0]}")
                shift
                ;;
            compact)
                sizes+=("${SIZE_VARIANTS[1]}")
                compact='true'
                shift
                ;;
            -*)
                break
                ;;
            *)
                echo "ERROR: Unrecognized size variant '${1:-}'."
                echo "Try '$0 --help' for more information."
                exit 1
                ;;
            esac
        done
        ;;
    --tweaks)
        shift
        for variant in $@; do
            case "$variant" in
            nord)
                nord="true"
                ctype="-nord"
                echo -e "Install Nord version! ..."
                shift
                ;;
            black)
                blackness="true"
                echo -e "Install Blackness version! ..."
                shift
                ;;
            rimless)
                rimless="true"
                echo -e "Install Rimless version! ..."
                shift
                ;;
            normal)
                normal="true"
                echo -e "Install Normal window button version! ..."
                shift
                ;;
            -*)
                break
                ;;
            *)
                echo "ERROR: Unrecognized tweaks variant '$1'."
                echo "Try '$0 --help' for more information."
                exit 1
                ;;
            esac
        done
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "ERROR: Unrecognized installation option '$1'."
        echo "Try '$0 --help' for more information."
        exit 1
        ;;
    esac
done

if [[ "${#themes[@]}" -eq 0 ]]; then
    themes=("${THEME_VARIANTS[0]}")
fi

if [[ "${#colors[@]}" -eq 0 ]]; then
    colors=("${COLOR_VARIANTS[@]}")
fi

if [[ "${#sizes[@]}" -eq 0 ]]; then
    sizes=("${SIZE_VARIANTS[0]}")
fi

#  Check command avalibility
function has_command() {
    command -v $1 >/dev/null
}

#  Install needed packages
install_package() {
    if [ ! "$(which sassc 2>/dev/null)" ]; then
        echo sassc needs to be installed to generate the css.
        if has_command zypper; then
            sudo zypper in sassc
        elif has_command apt-get; then
            sudo apt-get install sassc
        elif has_command dnf; then
            sudo dnf install sassc
        elif has_command dnf; then
            sudo dnf install sassc
        elif has_command pacman; then
            sudo pacman -S --noconfirm sassc
        fi
    fi
}

tweaks_temp() {
    cp -rf ${SRC_DIR}/sass/_tweaks.scss ${SRC_DIR}/sass/_tweaks-temp.scss
}

compact_size() {
    sed -i "/\$compact:/s/false/true/" ${SRC_DIR}/sass/_tweaks-temp.scss
}

nord_color() {
    sed -i "/\$color_type:/s/default/nord/" ${SRC_DIR}/sass/_tweaks-temp.scss
}

blackness_color() {
    sed -i "/\$color_type:/s/default/blackness/" ${SRC_DIR}/sass/_tweaks-temp.scss
}

border_rimless() {
    sed -i "/\$rimless:/s/false/true/" ${SRC_DIR}/sass/_tweaks-temp.scss
}

normal_winbutton() {
    sed -i "/\$window_button:/s/mac/normal/" ${SRC_DIR}/sass/_tweaks-temp.scss
}

theme_color() {
    if [[ "$theme" != '' ]]; then
        case "$theme" in
        -purple)
            theme_color='purple'
            ;;
        -pink)
            theme_color='pink'
            ;;
        -red)
            theme_color='red'
            ;;
        -green)
            theme_color='green'
            ;;
        -cyan)
            theme_color='cyan'
            ;;
        esac
        sed -i "/\$theme:/s/default/${theme_color}/" ${SRC_DIR}/sass/_tweaks-temp.scss
    fi
}

theme_tweaks() {
    if [[ "$accent" == 'true' || "$compact" == 'true' || "$nord" == 'true' || "$rimless" == 'true' || "$blackness" == 'true' || "$normal" == 'true' ]]; then
        tweaks='true'
        install_package
        tweaks_temp
    fi

    if [[ "$accent" = "true" ]]; then
        theme_color
    fi

    if [[ "$compact" = "true" ]]; then
        compact_size
    fi

    if [[ "$nord" = "true" ]]; then
        nord_color
    fi

    if [[ "$blackness" = "true" ]]; then
        blackness_color
    fi

    if [[ "$rimless" = "true" ]]; then
        border_rimless
    fi

    if [[ "$normal" = "true" ]]; then
        normal_winbutton
    fi
}

install_theme() {
    for theme in "${themes[@]}"; do
        for color in "${colors[@]}"; do
            for size in "${sizes[@]}"; do
                install "${dest:-$DEST_DIR}" "${_name:-$THEME_NAME}" "$theme" "$color" "$size" "$ctype"
            done
        done
    done
}

install_theme

echo
echo Done.
