#!/bin/bash

install_missing_packages() {
	local pkg="$1"
	shift || true
	local pkg_candidates=("$@")
	if ((${#pkg_candidates[@]} == 0)); then
		mapfile -t pkg_candidates < <(arch_package_candidates "$pkg")
	fi

	if command -v yay >/dev/null 2>&1; then
		echo "==> installing missing package: ${pkg_candidates[*]}"
		if yay -S --needed --noconfirm "${pkg_candidates[@]}"; then
			return 0
		fi
		return 1
	fi

	if command -v pacman >/dev/null 2>&1; then
		local pacman_candidates=()
		for candidate in "${pkg_candidates[@]}"; do
			pacman_candidates+=("${candidate##*/}")
		done
		echo "==> installing missing package: ${pacman_candidates[*]}"
		if sudo pacman -S --needed --noconfirm "${pacman_candidates[@]}"; then
			return 0
		fi
		return 1
	fi

	return 1
}
