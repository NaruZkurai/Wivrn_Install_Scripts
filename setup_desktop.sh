#!/bin/bash

setup_desktop() {
	local applications_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/applications"
	local desktop_file="${applications_dir}/io.github.wivrn.wivrn.desktop"

	install -Dm644 /dev/stdin "$desktop_file" <<EOF
[Desktop Entry]
Type=Application
Name=WiVRn
Comment=WiVRn dashboard
Exec=${BIN_DIR}/wivrn-dashboard
TryExec=${BIN_DIR}/wivrn-dashboard
Icon=io.github.wivrn.wivrn
Terminal=false
Categories=Utility;
EOF
	echo "==> installed desktop entry at ${desktop_file}"
}