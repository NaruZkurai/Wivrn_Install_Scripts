#!/bin/bash

package_is_installed() {
	local candidate="$1"
	local package_name="${candidate##*/}"
	command -v pacman >/dev/null 2>&1 && pacman -Q "$package_name" >/dev/null 2>&1
}

install_missing_packages() {
	local pkg="$1"
	shift || true
	local pkg_candidates=("$@")
	if ((${#pkg_candidates[@]} == 0)); then
		mapfile -t pkg_candidates < <(arch_package_candidates "$pkg")
	fi

	if command -v yay >/dev/null 2>&1; then
		for candidate in "${pkg_candidates[@]}"; do
			echo "==> installing missing package: ${candidate}"
				if yay -S --needed --noconfirm "$candidate" && package_is_installed "$candidate"; then
				return 0
			fi
		done
		return 1
	fi

	if command -v pacman >/dev/null 2>&1; then
		for candidate in "${pkg_candidates[@]}"; do
			echo "==> installing missing package: ${candidate}"
			if sudo pacman -S --needed --noconfirm "$candidate"; then
				return 0
			fi
		done
		return 1
	fi

	return 1
}
