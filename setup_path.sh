#!/bin/bash

setup_path() {
	local profile="${HOME}/.profile"
	local bin_dir="$BIN_DIR"
	local data_dir="${PREFIX}/share"
	local path_line="export PATH=\"${bin_dir}:\$PATH\""
	local data_line="export XDG_DATA_DIRS=\"${data_dir}:\${XDG_DATA_DIRS:-/usr/local/share:/usr/share}\""
	if [[ ":${PATH}:" != *":${bin_dir}:"* ]]; then
		export PATH="${bin_dir}:${PATH}"
	fi
	if [[ ":${XDG_DATA_DIRS:-}:" != *":${data_dir}:"* ]]; then
		export XDG_DATA_DIRS="${data_dir}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
	fi

	if [[ ! -e "$profile" || -w "$profile" ]]; then
		if [[ ! -f "$profile" ]] || ! grep -Fqx "$path_line" "$profile" 2>/dev/null; then
			printf '\n# WiVRn installed binaries\n%s\n' "$path_line" >> "$profile"
		fi
		if [[ ! -f "$profile" ]] || ! grep -Fqx "$data_line" "$profile" 2>/dev/null; then
			printf '\n# WiVRn desktop integration\n%s\n' "$data_line" >> "$profile"
		fi
	else
		echo "warning: add ${bin_dir} to PATH in your shell profile" >&2
		echo "warning: add ${data_dir} to XDG_DATA_DIRS in your shell profile" >&2
	fi
}