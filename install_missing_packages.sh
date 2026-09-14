#!/bin/bash

package_is_installed() {
	local candidate="$1"
	local package_name="${candidate##*/}"
	command -v pacman >/dev/null 2>&1 && pacman -Q "$package_name" >/dev/null 2>&1
}

package_candidate_available() {
	local candidate="$1"
	if command -v yay >/dev/null 2>&1; then
		yay -Si "$candidate" >/dev/null 2>&1
	elif command -v pacman >/dev/null 2>&1; then
		pacman -Si "$candidate" >/dev/null 2>&1
	else
		return 1
	fi
}

select_package_candidate() {
	local candidate
	for candidate in "$@"; do
		if package_candidate_available "$candidate"; then
			printf '%s\n' "$candidate"
			return 0
		fi
	done
	return 1
}

install_missing_packages() {
	local mode="packages"
	local pkg
	local selected
	local selected_packages=()
	local pkg_candidates=()

	if [[ "${1:-}" == "--alternatives" ]]; then
		mode="alternatives"
		shift
	fi

	if [[ "$mode" == "alternatives" ]]; then
		mapfile -t pkg_candidates < <(arch_package_candidates "$1")
		shift
		pkg_candidates+=("$@")
		if ! selected="$(select_package_candidate "${pkg_candidates[@]}")"; then
			echo "error: no package candidate is available: ${pkg_candidates[*]}" >&2
			return 1
		fi
		selected_packages+=("$selected")
	else
		for pkg in "$@"; do
			mapfile -t pkg_candidates < <(arch_package_candidates "$pkg")
			if ! selected="$(select_package_candidate "${pkg_candidates[@]}")"; then
				echo "error: no package candidate is available for '$pkg'" >&2
				return 1
			fi
			selected_packages+=("$selected")
		done
	fi

	if ! confirm_package_install "${selected_packages[*]}"; then
		return 1
	fi

	echo "==> installing missing packages: ${selected_packages[*]}"
	if command -v yay >/dev/null 2>&1; then
		yay -S --needed --noconfirm "${selected_packages[@]}" || return 1
	else
		sudo pacman -S --needed --noconfirm "${selected_packages[@]}" || return 1
	fi

	for selected in "${selected_packages[@]}"; do
		if ! package_is_installed "$selected"; then
			echo "error: package was not installed: ${selected}" >&2
			return 1
		fi
		done
}
