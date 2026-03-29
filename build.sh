#!/bin/bash
WIDGET_DIR="ai-stat"
PLASMOID_FILE="ai-stat.plasmoid"

echo "Creating ${PLASMOID_FILE}..."
rm -f "${PLASMOID_FILE}"
zip -r "${PLASMOID_FILE}" "${WIDGET_DIR}/" \
    -x "${WIDGET_DIR}/.git/*"

if [ -f "${PLASMOID_FILE}" ]; then
    echo "Created ${PLASMOID_FILE} successfully!"
    echo ""
    echo "Install with:  kpackagetool6 -t Plasma/Applet -i ${PLASMOID_FILE}"
    echo "Upgrade with:  kpackagetool6 -t Plasma/Applet -u ${PLASMOID_FILE}"
    echo "Remove with:   kpackagetool6 -t Plasma/Applet -r ai-stat"
else
    echo "Error creating ${PLASMOID_FILE}"
    exit 1
fi
