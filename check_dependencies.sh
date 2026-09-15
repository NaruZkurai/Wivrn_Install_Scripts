#!/bin/bash

dependency_package_name() {
	local raw="$1"
	local name="${raw,,}"

	# Names coming from "missing: X" entries can be CMake variables such as
	# Vulkan_INCLUDE_DIR or Vulkan_LIBRARY. Strip the suffix so the mapping
	# below matches the Find module name.
	if [[ "$name" == *_include_dir || "$name" == *_library || "$name" == *_libraries ]]; then
		name="${name%%_*}"
	fi

	case "$name" in
		ecm)
		printf '%s\n' 'extra-cmake-modules'
		;;
		vulkan)
		# CMake's FindVulkan reports "Vulkan", and the observed failure is a
		# missing Vulkan_INCLUDE_DIR. On Arch/CachyOS there is no package
		# literally named "vulkan": the headers live in vulkan-headers and
		# the loader/ICD in vulkan-icd-loader.
		printf '%s\n' 'vulkan-headers'
		;;
		x264)
		printf '%s\n' 'x264'
		;;
		libav|libavcodec|libavutil)
		printf '%s\n' 'ffmpeg'
		;;
		libdrm)
		printf '%s\n' 'libdrm'
		;;
		libpipewire)
		printf '%s\n' 'pipewire'
		;;
			gdbus_codegen|gdbus-codegen)
			printf '%s\n' 'glib2-devel'
			;;
		*)
		printf '%s\n' "$name"
			;;
	esac
}

install_detected_dependencies() {
	local configure_log="$1"
	local dependency
	local package_name
	local dependencies=()
	local packages=()

	mapfile -t dependencies < <(
		sed -nE \
			-e 's/.*Could NOT find ([A-Za-z0-9_.+-]+).*/\1/p' \
			-e 's/.*Could not find ([A-Za-z0-9_.+-]+).*/\1/p' \
			-e 's/.*provided by "([^"]+)".*/\1/p' \
			"$configure_log" | awk '!seen[$0]++'
	)

	if ((${#dependencies[@]} == 0)); then
		echo "error: CMake configuration failed without identifying a missing dependency" >&2
		echo "==== last 40 lines of ${configure_log} ====" >&2
		tail -n 40 "$configure_log" >&2 || true
		echo "==========================================" >&2
		return 1
	fi

	for dependency in "${dependencies[@]}"; do
		# "missing: Vulkan_INCLUDE_DIR" style entries name a CMake variable,
		# not a package. Reduce to the Find module prefix (Vulkan).
		package_name="$(dependency_package_name "$dependency")"
		echo "==> detected missing dependency: ${dependency} (package: ${package_name})" >&2
		packages+=("$package_name")
	done

	mapfile -t packages < <(printf '%s\n' "${packages[@]}" | awk '!seen[$0]++')

	install_missing_packages "${packages[@]}"
}

# Proactively verify the Vulkan headers/loader are present before CMake runs.
# Without this, find_package(Vulkan REQUIRED) fails with:
#   Could NOT find Vulkan (missing: Vulkan_INCLUDE_DIR)
#   Found version ""
# which is unhelpful because the version comes out empty and the log parser
# only sees a generic "missing:" line.
ensure_vulkan_headers() {
	local header="/usr/include/vulkan/vulkan_core.h"

	if [[ -r "$header" ]]; then
		return 0
	fi

	echo "==> Vulkan headers not found at ${header}" >&2
	echo "==> required by find_package(Vulkan REQUIRED) in CMakeLists.txt" >&2

	if ! command -v pacman >/dev/null 2>&1 && ! command -v yay >/dev/null 2>&1; then
		echo "error: install vulkan-headers with your distro's package manager" >&2
		return 1
	fi

	install_missing_packages --alternatives vulkan-headers vulkan-headers || return 1

	if [[ ! -r "$header" ]]; then
		echo "error: vulkan-headers installed but ${header} is still missing" >&2
		return 1
	fi

	# The headers alone are not enough to link or run; the ICD loader is a
	# runtime dependency for the server and the OpenXR library.
	if ! command -v pacman >/dev/null 2>&1 || ! pacman -Q vulkan-icd-loader >/dev/null 2>&1; then
		install_missing_packages --alternatives vulkan-icd-loader vulkan-icd-loader || true
	fi

	return 0
}
