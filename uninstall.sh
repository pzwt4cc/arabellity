#!/bin/sh
set -e

NAME="arabellity"

if [ "$1" = "--user" ] || [ "$(id -u)" -ne 0 ]; then
    PREFIX="${HOME}/.local"
else
    PREFIX="${PREFIX:-/usr/local}"
fi

BINDIR="${PREFIX}/bin"
DATADIR="${PREFIX}/share"
APPDIR="${DATADIR}/applications"
ICONDIR="${DATADIR}/icons/hicolor"

echo "==> Uninstalling ${NAME} from ${PREFIX}..."

rm -f "${BINDIR}/${NAME}"
rm -f "${APPDIR}/${NAME}.desktop"
rm -f "${ICONDIR}/scalable/apps/${NAME}.svg"

for s in 16 32 48 64 128 256; do
    rm -f "${ICONDIR}/${s}x${s}/apps/${NAME}.png"
done

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${APPDIR}" 2>/dev/null || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q "${ICONDIR}" 2>/dev/null || true
fi

echo "==> ${NAME} successfully uninstalled from ${PREFIX}."
