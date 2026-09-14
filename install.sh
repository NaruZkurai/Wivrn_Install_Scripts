#!/bin/bash
#
# install.sh — build and install WiVRn from this git checkout.
#
# Explicit commands:
#   bash ./install.sh                 # build and install 64-bit WiVRn
#   bash ./install.sh --buildonly     # build only
#   bash ./install.sh --installonly   # install an existing build
#   bash ./install.sh --reinstall     # reinstall and rerun post-install setup
#   bash ./install.sh --path /opt/wivrn
#   bash ./install.sh --path /nzk/bin/ # puts wivrn-server, wivrnctl, and wivrn-dashboard in /nzk/bin/
#   bash ./install.sh -p /opt/wivrn
#
# With exactly `bash ./install.sh` and no options, these are the effective settings:
#   ENABLED:  build, install, dashboard, LTO, server, server OpenXR library,
#             wivrnctl, VAAPI, x264, NVENC, Vulkan encode, SteamVR Lighthouse
#   DISABLED: install-only, build-only, reinstall, multilib/32-bit, client,
#             dissector, WIVRN_WERROR
#   VALUES:   prefix=$HOME/.local, build-dir=<repo>/build-install,
#             build-type=Release, CPU=auto, jobs=nproc,
#             OpenXR manifest=relative
#   CMAKE:    -DWIVRN_BUILD_SERVER=ON -DWIVRN_BUILD_SERVER_LIBRARY=ON
#             -DWIVRN_BUILD_WIVRNCTL=ON -DWIVRN_BUILD_DASHBOARD=ON
#             -DWIVRN_BUILD_CLIENT=OFF -DWIVRN_BUILD_DISSECTOR=OFF
#             -DWIVRN_OPENXR_MANIFEST_TYPE=relative
#             -DWIVRN_USE_VAAPI=ON -DWIVRN_USE_X264=ON
#             -DWIVRN_USE_NVENC=ON -DWIVRN_USE_VULKAN_ENCODE=ON
#             -DWIVRN_FEATURE_STEAMVR_LIGHTHOUSE=ON
#             -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=ON -DWIVRN_WERROR=OFF
#
# CPU tuning is automatic. If the CPU is AMD Zen 3 or Zen 4, the matching
# -march=znver3 / -march=znver4 is used. Otherwise it falls back to
# -march=native (or generic if native is unsupported).
#
# You can still override the detection manually if you want:
#   --cpu=native | znver4 | znver3 | znver2 | znver1 | generic
#
set -euo pipefail

# ---------------------------------------------------------------- defaults ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
. "${SCRIPT_DIR}/detect_cpu_arch.sh"
. "${SCRIPT_DIR}/arch_package_candidates.sh"
. "${SCRIPT_DIR}/install_missing_packages.sh"
. "${SCRIPT_DIR}/ensure_tool.sh"
. "${SCRIPT_DIR}/check_dependencies.sh"
. "${SCRIPT_DIR}/confirm_package_install.sh"
BUILD_DIR="${REPO_DIR}/build-install"
BUILD_TYPE="Release"
PREFIX="${HOME}/.local"
CPU_TARGET="auto"   # auto-detect znver4 / znver3, else native
JOBS="$(nproc 2>/dev/null || echo 4)"
DO_SUDO_INSTALL=0
WITH_DASHBOARD=1
LTO=1
INSTALL_ONLY=0
BUILD_ONLY=0
REINSTALL=0
WITH_MULTILIB=0

# --------------------------------------------------------------- arg parse ---
usage() {
	cat <<'EOF'
Usage: ./install-wivrn.sh [options]

Options:
  --cpu=<target>     Override auto-detection: native, znver4, znver3,
                     znver2, znver1, generic. Aliases: zen4, zen3, zencver4...
                     Default is auto: znver4/znver3 when the CPU supports it,
                     otherwise native.
	--prefix=<path>    Install prefix (default: $HOME/.local)
	--path=<path>, -p  Alias for --prefix; accepts -p <path> too
  --build-dir=<path> Build directory (default: <repo>/build-install)
  --build-type=<t>   CMAKE_BUILD_TYPE (default: Release)
  --jobs=<n>         Parallel build jobs (default: nproc)
  --no-lto           Disable interprocedural optimization / LTO
  --no-dashboard     Skip the Qt dashboard (server + wivrnctl only)
	--multilib         Also build and install the 32-bit OpenXR server library
	--installonly, -io Skip building; install the existing build output
	--reinstall, -ri   Reinstall the existing build output and rerun setup
	--buildonly, -bo   Build only; skip installation and host setup
  --not-root         Allow installing into a system prefix without sudo
	-nb, --nobuild     Deprecated alias for --installonly
  -h, --help         Show this help

Notes:
  * Presets in CMakePresets.json are untouched; a dedicated build dir is used.
  * If --prefix is not writable by you, sudo is used automatically.
  * Tuning flags are appended last so they win over the project's own flags.
  * No flags are required: just run ./install.sh
EOF
}

# Option effects:
#   --path/-p PATH       sets PREFIX=PATH
#   --buildonly/-bo      sets BUILD_ONLY=1; build, then stop before install
#   --installonly/-io    sets INSTALL_ONLY=1; skip build and install existing output
#   --reinstall/-ri      sets REINSTALL=1, then INSTALL_ONLY=1; reinstall existing output
#   --multilib           sets WITH_MULTILIB=1; also build/install the 32-bit runtime
#   --nobuild/-nb        sets INSTALL_ONLY=1 (legacy alias)
while (($#)); do
	arg="$1"
	case "$arg" in
		--cpu=*)        CPU_TARGET="${arg#*=}"; shift ;;
		--prefix=*|--path=*|-p=*) PREFIX="${arg#*=}"; shift ;;
		--prefix|--path|-p)
			if (($# < 2)); then
				echo "error: $arg requires a path" >&2
				exit 2
			fi
			PREFIX="$2"
			shift 2
			;;
		--build-dir=*)  BUILD_DIR="${arg#*=}"; shift ;;
		--build-type=*) BUILD_TYPE="${arg#*=}"; shift ;;
		--jobs=*|-j*)   JOBS="${arg#*=}"; shift ;;
		--no-lto)       LTO=0; shift ;;
		--no-dashboard) WITH_DASHBOARD=0; shift ;;
		--multilib)     WITH_MULTILIB=1; shift ;;
		--installonly|-io) INSTALL_ONLY=1; shift ;;
		--reinstall|-ri) REINSTALL=1; shift ;;
		--buildonly|-bo) BUILD_ONLY=1; shift ;;
		--not-root)     DO_SUDO_INSTALL=1; shift ;;
		-nb|--nobuild)  INSTALL_ONLY=1; shift ;;
		-h|--help)      usage; exit 0 ;;
		*) echo "error: unknown option '$arg'" >&2; usage >&2; exit 2 ;;
	esac
done

if (( INSTALL_ONLY && BUILD_ONLY )); then
	echo "error: --installonly and --buildonly cannot be used together" >&2
	exit 2
fi

if (( REINSTALL )); then
	INSTALL_ONLY=1
fi

# Root cause: CMake's install prefix is the tree root. If a user passes a final
# bin directory like /nzk/bin, we must install to /nzk and set bindir=bin.
# Otherwise CMake will append /bin again and produce /nzk/bin/bin.
PREFIX="${PREFIX%/}"
BIN_DIR="${PREFIX}/bin"
CMAKE_INSTALL_BINDIR="bin"
if [[ "${PREFIX}" == */bin ]]; then
	PREFIX="${PREFIX%/bin}"
	BIN_DIR="${PREFIX}/bin"
	CMAKE_INSTALL_BINDIR="bin"
fi

# ---------------------------------------------------------- cpu -> flags -----
if [[ "$CPU_TARGET" == "auto" ]]; then
	CPU_TARGET="$(detect_cpu_target)"
fi

MARCH=""
MTUNE=""
TUNE_HUMAN=""
case "$(normalise_cpu "$CPU_TARGET")" in
	native)
		MARCH="native"
		MTUNE="native"
		TUNE_HUMAN="native (host CPU)"
		;;
	znver1|znver2|znver3|znver4|znver5)
		TARGET="$(normalise_cpu "$CPU_TARGET")"
		MARCH="$TARGET"
		MTUNE="$TARGET"
		TUNE_HUMAN="$TARGET"
		;;
	generic|none|"")
		MARCH=""
		MTUNE=""
		TUNE_HUMAN="generic (no -march)"
		;;
	*)
		echo "error: unsupported --cpu value '$CPU_TARGET'" >&2
		echo "       use: auto, native, znver1..znver5, generic" >&2
		exit 2
		;;
esac

configure_cpu_flags

# ------------------------------------------------------------ preflight ------
need() {
	command -v "$1" >/dev/null 2>&1 || MISSING+=("$1")
}

MISSING=()
need cmake

if (( !INSTALL_ONLY )); then
	need ninja
	need pkg-config
	need cc
	need c++
	if (( WITH_DASHBOARD )); then
		need qmake6 || need qtpaths6 || true
	fi
	if (( WITH_MULTILIB )); then
		if ! printf 'int main(){}\n' | c++ -m32 -x c++ - -o /dev/null >/dev/null 2>&1; then
			echo "error: 32-bit compilation is unavailable; install multilib development packages or omit --multilib" >&2
			exit 1
		fi
	fi
fi
if ((${#MISSING[@]})); then
	if command -v pacman >/dev/null 2>&1 || command -v yay >/dev/null 2>&1; then
		echo "==> missing required tools: ${MISSING[*]}"
		echo "==> installing distro packages when possible"
		for tool in "${MISSING[@]}"; do
			case "$tool" in
				cmake) ensure_tool cmake cmake || true ;;
				ninja) ensure_tool ninja ninja || true ;;
				pkg-config) ensure_tool pkg-config pkgconf pkg-config || true ;;
				cc|c++) ensure_tool c++ gcc || true ;;
				qmake6|qtpaths6) ensure_tool qmake6 qt6-base qt6-tools || true ;;
			esac
		done
		for tool in cmake ninja pkg-config cc c++; do
			if ! command -v "$tool" >/dev/null 2>&1; then
				echo "error: missing required tool '$tool' after attempted install" >&2
				exit 1
			fi
		done
	else
		echo "error: missing required tools: ${MISSING[*]}" >&2
		echo "       install them with your distro's package manager and retry" >&2
		exit 1
	fi
fi

CMAKE_VER="$(cmake --version | head -n1 | awk '{print $3}')"
echo "==> cmake ${CMAKE_VER}, ninja, prefix: ${PREFIX}"

# ------------------------------------------------------------- configure -----
if (( INSTALL_ONLY )); then
	echo "==> skipping build (install-only mode)"
else
	echo "==> configuring (${BUILD_TYPE}, cpu: ${TUNE_HUMAN})"

CMAKE_ARGS=(
	-S "$REPO_DIR"
	-B "$BUILD_DIR"
	-G Ninja
	-DCMAKE_BUILD_TYPE="$BUILD_TYPE"
	-DCMAKE_INSTALL_PREFIX="$PREFIX"
	-DCMAKE_INSTALL_BINDIR="$CMAKE_INSTALL_BINDIR"
	-DCMAKE_C_FLAGS="$CFLAGS_EXTRA"
	-DCMAKE_CXX_FLAGS="$CXXFLAGS_EXTRA"
	-DCMAKE_INTERPROCEDURAL_OPTIMIZATION="$([[ $LTO == 1 ]] && echo ON || echo OFF)"
	-DCMAKE_EXPORT_COMPILE_COMMANDS=ON
	-DWIVRN_BUILD_SERVER=ON
	-DWIVRN_BUILD_SERVER_LIBRARY=ON
	-DWIVRN_BUILD_WIVRNCTL=ON
	-DWIVRN_BUILD_CLIENT=OFF
	-DWIVRN_BUILD_DISSECTOR=OFF
	-DWIVRN_OPENXR_MANIFEST_TYPE=relative
	-DWIVRN_USE_VAAPI=ON
	-DWIVRN_USE_X264=ON
	-DWIVRN_USE_NVENC=ON
	-DWIVRN_USE_VULKAN_ENCODE=ON
	-DWIVRN_FEATURE_STEAMVR_LIGHTHOUSE=ON
	-DWIVRN_WERROR=OFF
)

if (( WITH_DASHBOARD )); then
	CMAKE_ARGS+=(
		-DWIVRN_BUILD_DASHBOARD=ON
		-DQT_QML_GENERATE_QMLLS_INI=ON
	)
else
	CMAKE_ARGS+=(-DWIVRN_BUILD_DASHBOARD=OFF)
fi

CONFIGURE_LOG="${BUILD_DIR}/configure.log"
CONFIGURE_ATTEMPT=0
while true; do
	if cmake "${CMAKE_ARGS[@]}" 2>&1 | tee "$CONFIGURE_LOG"; then
		break
	fi

	((CONFIGURE_ATTEMPT += 1))
	if (( CONFIGURE_ATTEMPT > 10 )); then
		echo "error: CMake configuration failed after 10 dependency attempts" >&2
		exit 1
	fi
	if ! install_detected_dependencies "$CONFIGURE_LOG"; then
		exit 1
	fi
	echo "==> retrying configure after installing detected dependencies"
done

# ---------------------------------------------------------------- build ------
echo "==> building with ${JOBS} job(s)"
cmake --build "$BUILD_DIR" --parallel "$JOBS"

if (( WITH_MULTILIB )); then
	echo "==> configuring 32-bit OpenXR server library"
	MULTILIB_BUILD_DIR="${BUILD_DIR}-32"
	MULTILIB_PKG_CONFIG_PATH="/usr/lib32/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
	MULTILIB_CMAKE_ARGS=(
		-S "$REPO_DIR"
		-B "$MULTILIB_BUILD_DIR"
		-G Ninja
		-DCMAKE_BUILD_TYPE="$BUILD_TYPE"
		-DCMAKE_INSTALL_PREFIX="$PREFIX"
		-DCMAKE_INSTALL_LIBDIR=lib32
		-DCMAKE_C_FLAGS="-m32 ${CFLAGS_EXTRA}"
		-DCMAKE_CXX_FLAGS="-m32 ${CXXFLAGS_EXTRA}"
		-DCMAKE_EXPORT_COMPILE_COMMANDS=ON
		-DWIVRN_BUILD_SERVER=OFF
		-DWIVRN_BUILD_SERVER_LIBRARY=ON
		-DWIVRN_BUILD_WIVRNCTL=OFF
		-DWIVRN_BUILD_CLIENT=OFF
		-DWIVRN_BUILD_DASHBOARD=OFF
		-DWIVRN_OPENXR_MANIFEST_TYPE=relative
		-DWIVRN_OPENXR_MANIFEST_ABI=ON
		-DVulkan_LIBRARY=/usr/lib32/libvulkan.so
		-DVulkan_INCLUDE_DIR=/usr/include
		-DWIVRN_WERROR=OFF
	)
	PKG_CONFIG_PATH="$MULTILIB_PKG_CONFIG_PATH" cmake "${MULTILIB_CMAKE_ARGS[@]}"
	echo "==> building 32-bit OpenXR server library with ${JOBS} job(s)"
	cmake --build "$MULTILIB_BUILD_DIR" --parallel "$JOBS"
fi

fi  # INSTALL_ONLY

if (( BUILD_ONLY )); then
	echo "==> build-only mode: skipping installation and host setup"
exit 0
fi

# -------------------------------------------------------------- install ------
# Figure out whether we can write to the prefix, else escalate.
SUDO=()
if [[ "$PREFIX" == "$HOME"* || "$PREFIX" == /tmp/* ]]; then
	:
elif [[ -w "$PREFIX" || ( ! -e "$PREFIX" && -w "$(dirname -- "$PREFIX")" ) ]]; then
	:
elif (( DO_SUDO_INSTALL )); then
	SUDO=(sudo)
else
	if command -v sudo >/dev/null 2>&1; then
		SUDO=(sudo)
		echo "==> ${PREFIX} is not user-writable, using sudo for install"
	else
		echo "error: ${PREFIX} is not writable and sudo is unavailable" >&2
		echo "       rerun with --prefix=\"\$HOME/.local\"" >&2
		exit 1
	fi
fi

echo "==> installing to ${PREFIX}"
"${SUDO[@]}" cmake --install "$BUILD_DIR"
if (( WITH_MULTILIB )); then
	"${SUDO[@]}" cmake --install "${BUILD_DIR}-32"
fi

echo "==> installing Pressure Vessel OpenXR environment"
"${SUDO[@]}" install -Dm644 /dev/stdin "${PREFIX}/lib/environment.d/wivrn.conf" <<'EOF'
PRESSURE_VESSEL_IMPORT_OPENXR_1_RUNTIMES=1
EOF

# ---------------------------------------------------------- host setup -------
HOST_SUDO=("${SUDO[@]}")
if (( EUID != 0 )) && ((${#HOST_SUDO[@]} == 0)) && command -v sudo >/dev/null 2>&1; then
	HOST_SUDO=(sudo)
fi

. "${SCRIPT_DIR}/run_optional.sh"
. "${SCRIPT_DIR}/setup_path.sh"
. "${SCRIPT_DIR}/setup_avahi.sh"
. "${SCRIPT_DIR}/setup_wivrn_service.sh"
. "${SCRIPT_DIR}/setup_frewall.sh"

echo "==> configuring PATH, Avahi, WiVRn service, and firewall"
setup_path
setup_avahi
setup_wivrn_service
setup_firewall

# --------------------------------------------------------------- finish ------
cat <<EOF

==> Done.

Binaries : ${BIN_DIR}/wivrn-server, ${BIN_DIR}/wivrn-dashboard
Runtime  : OpenXR manifest + systemd user unit (wivrn) were installed.

Setup     : PATH, Avahi, WiVRn user service, and firewall were configured.
Tuned for : ${TUNE_HUMAN}
EOF
