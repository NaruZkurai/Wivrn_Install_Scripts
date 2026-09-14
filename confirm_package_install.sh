#!/bin/bash

confirm_package_install() {
	local packages="$1"
	local answer=""

	if [[ ! -t 0 && ! -t 1 && ! -t 2 ]]; then
		echo "error: human confirmation is required before installing: ${packages}" >&2
		return 1
	fi

	printf 'Install required package candidate(s): %s? [y/N] ' "$packages" >&2
	if ! read -r answer </dev/tty; then
		return 1
	fi

	case "${answer,,}" in
		y|yes) return 0 ;;
		*)
			echo "==> package installation declined" >&2
			return 1
			;;
	esac
}
