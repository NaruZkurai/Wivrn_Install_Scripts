#!/bin/bash

setup_global_data_path() {
	local data_dir="${PREFIX}/share"
	local profile_script="/etc/profile.d/wivrn.sh"

	if ((${#HOST_SUDO[@]} == 0)) && (( EUID != 0 )); then
		echo "warning: cannot configure global XDG_DATA_DIRS without root privileges" >&2
		return 0
	fi

	"${HOST_SUDO[@]}" install -Dm644 /dev/stdin "${profile_script}" <<EOF
# WiVRn desktop integration
if [[ ":\${XDG_DATA_DIRS:-}:" != *":${data_dir}:"* ]]; then
    export XDG_DATA_DIRS="${data_dir}:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
fi
EOF
}
