#!/bin/bash

arch_package_candidates() {
	local pkg="$1"
	local cpu_family=""
	local variant=""
	local repositories=()
	local repository
	local candidate

	if [[ -r /proc/cpuinfo ]]; then
		cpu_family="$(awk -F': ' '/^cpu family/{print $2; exit}' /proc/cpuinfo)"
		case "$cpu_family" in
			25|26) variant="znver4" ;;
		esac
	fi

	if [[ -n "$variant" ]]; then
		repositories+=("cachyos-extra-${variant}")
	fi
	repositories+=(cachyos-extra cachyos extra core)

	for repository in "${repositories[@]}"; do
		candidate="${repository}/${pkg}"
		printf '%s\n' "$candidate"
	done
	printf '%s\n' "$pkg"
}
