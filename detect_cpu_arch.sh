#!/bin/bash

# Normalise the user's spelling ("zencver4", "zen4", "ZNVER4", "zver3" ...).
# The common typo is "zencver" (extra c); strip it, then map zen->znver.
normalise_cpu() {
	printf '%s' "$1" |
		tr '[:upper:]' '[:lower:]' |
		sed -e 's/zncver/znver/' -e 's/^zver/znver/' -e 's/^zen/znver/'
}

# Work out which -march the host CPU can actually use.
# Zen 3 => znver3, Zen 4/5 => znver4. Anything else => native.
detect_cpu_target() {
	local model="" vendor="" family="" cpuinfo=""

	# Prefer the explicit "cpu family" / "model" numbers from /proc/cpuinfo.
	if [[ -r /proc/cpuinfo ]]; then
		cpuinfo="$(cat /proc/cpuinfo)"
		vendor="$(awk -F': ' '/^vendor_id/{print $2; exit}' /proc/cpuinfo)"
		family="$(awk -F': ' '/^cpu family/{print $2; exit}' /proc/cpuinfo)"
		model="$(awk -F': ' '/^model[[:space:]]*:/{print $2; exit}' /proc/cpuinfo)"
	fi

	if [[ "$vendor" == "AuthenticAMD" ]]; then
		# Family 0x19 (25) = Zen 3 / Zen 4 family.
		# Model >= 0x10 on family 25 is Zen 4; below is Zen 3.
		if [[ "$family" == "25" ]]; then
			if [[ -n "$model" && "$model" -ge 16 ]] 2>/dev/null; then
				printf 'znver4\n'
				return
			fi
			printf 'znver3\n'
			return
		fi
		# Family 0x1A (26) = Zen 5 (Ryzen 9000/AI 300), still znver4-capable.
		if [[ "$family" == "26" ]]; then
			printf 'znver4\n'
			return
		fi
	fi

	printf 'native\n'
}

configure_cpu_flags() {
	# Sanity-check that the chosen GCC/Clang actually knows this -march.
	# If an -march is not supported by the compiler, fall back to native.
	if [[ -n "$MARCH" && "$MARCH" != "native" ]]; then
		CXX_BIN="${CXX:-c++}"
		if ! echo 'int main(){}' | "$CXX_BIN" -march="$MARCH" -x c++ - -o /dev/null 2>/dev/null; then
			echo "warning: ${CXX_BIN} does not support -march=${MARCH}, falling back to native" >&2
			MARCH="native"
			MTUNE="native"
			TUNE_HUMAN="native (fallback: compiler lacks ${MARCH})"
		fi
	fi

	CFLAGS_EXTRA="-O3"
	CXXFLAGS_EXTRA="-O3"
	if [[ -n "$MARCH" ]]; then
		CFLAGS_EXTRA="${CFLAGS_EXTRA} -march=${MARCH} -mtune=${MTUNE} -fno-semantic-interposition"
		CXXFLAGS_EXTRA="${CXXFLAGS_EXTRA} -march=${MARCH} -mtune=${MTUNE} -fno-semantic-interposition"
	fi
}
