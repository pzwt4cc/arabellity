#!/bin/sh
set -e

NAME="arabellity"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ "$1" = "--user" ] || [ "$(id -u)" -ne 0 ]; then
    PREFIX="${HOME}/.local"
    DEFAULT_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$NAME"
else
    PREFIX="${PREFIX:-/usr/local}"
    DEFAULT_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$NAME"
fi

BINDIR="${PREFIX}/bin"
DATADIR="${PREFIX}/share"
APPDIR="${DATADIR}/applications"
ICONDIR="${DATADIR}/icons/hicolor"

echo "==> Installing ${NAME} to ${PREFIX}..."

if [ ! -f "${SCRIPT_DIR}/build/${NAME}" ]; then
    echo "==> Building ${NAME}..."
    (cd "${SCRIPT_DIR}" && make)
fi

mkdir -p "${BINDIR}" "${APPDIR}"

install -m 755 "${SCRIPT_DIR}/build/${NAME}" "${BINDIR}/${NAME}"
echo "  -> Installed binary: ${BINDIR}/${NAME}"

if [ -f "${SCRIPT_DIR}/assets/${NAME}.desktop" ]; then
    install -m 644 "${SCRIPT_DIR}/assets/${NAME}.desktop" "${APPDIR}/${NAME}.desktop"
    echo "  -> Installed desktop entry: ${APPDIR}/${NAME}.desktop"
fi

if [ -f "${SCRIPT_DIR}/assets/icons/${NAME}.svg" ]; then
    mkdir -p "${ICONDIR}/scalable/apps"
    install -m 644 "${SCRIPT_DIR}/assets/icons/${NAME}.svg" "${ICONDIR}/scalable/apps/${NAME}.svg"
    echo "  -> Installed scalable icon: ${ICONDIR}/scalable/apps/${NAME}.svg"
fi

for s in 16 32 48 64 128 256; do
    png_file="${SCRIPT_DIR}/assets/icons/${NAME}-${s}x${s}.png"
    if [ -f "${png_file}" ]; then
        mkdir -p "${ICONDIR}/${s}x${s}/apps"
        install -m 644 "${png_file}" "${ICONDIR}/${s}x${s}/apps/${NAME}.png"
    fi
done

if [ ! -f "${DEFAULT_CONF_DIR}/${NAME}.conf" ] && [ -f "${SCRIPT_DIR}/${NAME}.conf" ]; then
    mkdir -p "${DEFAULT_CONF_DIR}"
    install -m 644 "${SCRIPT_DIR}/${NAME}.conf" "${DEFAULT_CONF_DIR}/${NAME}.conf"
    echo "  -> Created default config: ${DEFAULT_CONF_DIR}/${NAME}.conf"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APPDIR}" 2>/dev/null || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q "${ICONDIR}" 2>/dev/null || true
fi

echo ""
echo "==> Installation complete! You can now run '${NAME}'."
