#!/bin/bash

setup_path() {
	local profile="${HOME}/.profile"
	local bin_dir="$BIN_DIR"
	local path_line="export PATH=\"${bin_dir}:\$PATH\""
	if [[ ":${PATH}:" != *":${bin_dir}:"* ]]; then
		export PATH="${bin_dir}:${PATH}"
	fi

	if [[ "$PREFIX" == "$HOME"/* && ( ! -e "$profile" || -w "$profile" ) ]]; then
		if [[ ! -f "$profile" ]] || ! grep -Fqx "$path_line" "$profile" 2>/dev/null; then
			printf '\n# WiVRn installed binaries\n%s\n' "$path_line" >> "$profile"
		fi
	else
		echo "warning: add ${PREFIX} to PATH in your shell profile" >&2
	fi
}