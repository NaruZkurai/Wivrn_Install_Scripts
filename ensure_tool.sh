#!/bin/bash

ensure_tool() {
	local tool="$1"
	local pkg_name="$2"
	shift 2 || true
	if command -v "$tool" >/dev/null 2>&1; then
		return 0
	fi
	if install_missing_packages --alternatives "$pkg_name" "$@"; then
		return 0
	fi
	return 1
}
