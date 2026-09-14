#!/bin/bash

dependency_package_name() {
	case "${1,,}" in
		ecm)
		printf '%s\n' 'extra-cmake-modules'
		;;
		*)
			printf '%s\n' "${1,,}"
			;;
	esac
}

install_detected_dependencies() {
	local configure_log="$1"
	local dependency
	local package_name
	local dependencies=()

	mapfile -t dependencies < <(
		sed -nE \
			-e 's/.*Could NOT find ([A-Za-z0-9_.+-]+).*/\1/p' \
			-e 's/.*provided by "([^"]+)".*/\1/p' \
			"$configure_log" | awk '!seen[$0]++'
	)

	if ((${#dependencies[@]} == 0)); then
		echo "error: CMake configuration failed without identifying a missing dependency" >&2
		return 1
	fi

	for dependency in "${dependencies[@]}"; do
		package_name="$(dependency_package_name "$dependency")"
		echo "==> detected missing dependency: ${dependency} (package: ${package_name})" >&2
		if ! install_missing_packages "$package_name"; then
			echo "error: dependency '${dependency}' could not be installed" >&2
			return 1
		fi
	done
}
