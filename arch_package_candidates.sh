#!/bin/bash

arch_package_candidates() {
	local pkg="$1"
	local cpu_family=""
	local vart=""
	local candidates=()

	if [[ -r /proc/cpuinfo ]]; then
		cpu_family="$(awk -F': ' '/^cpu family/{print $2; exit}' /proc/cpuinfo)"
		if [[ "$cpu_family" == "25" ]]; then
			vart="znver4"
		elif [[ "$cpu_family" == "26" ]]; then
			vart="znver4"
		fi
	fi

	if [[ -z "$vart" ]]; then
		if [[ -r /proc/cpuinfo ]]; then
			if awk -F': ' '/^model name/{print $2}' /proc/cpuinfo | grep -qi 'znver3'; then
				vart="znver3"
			fi
		fi
	fi

	case "$pkg" in
		boost)
			if [[ -n "$vart" ]]; then
				candidates+=("cachyos-extra-${vart}/boost" "cachyos-extra-${vart}/boost-libs")
			fi
			candidates+=("cachyos-extra/boost" "cachyos-extra/boost-libs" "extra/boost" "boost")
			candidates+=("boost-libs")
			;;
		*)
			candidates+=("$pkg")
			;;
	esac

	printf '%s\n' "${candidates[@]}"
}
