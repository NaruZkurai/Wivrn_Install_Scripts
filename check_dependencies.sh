#!/bin/bash

check_boost_dependency() {
	local cxx_bin="${CXX:-c++}"
	local compiler_id="GNU"

	if "$cxx_bin" --version 2>&1 | grep -qi clang; then
		compiler_id="Clang"
	fi

	if cmake --find-package \
		-DNAME=Boost \
		-DCOMPILER_ID="$compiler_id" \
		-DLANGUAGE=CXX \
		-DMODE=EXIST >/dev/null 2>&1; then
		echo "==> Boost dependency found"
		return 0
	fi

	echo "==> Boost dependency is missing; installing package" >&2
	if ! install_missing_packages boost; then
		echo "error: Boost is required but could not be installed automatically" >&2
		return 1
	fi

	if ! cmake --find-package \
		-DNAME=Boost \
		-DCOMPILER_ID="$compiler_id" \
		-DLANGUAGE=CXX \
		-DMODE=EXIST >/dev/null 2>&1; then
		echo "error: Boost is still unavailable after package installation" >&2
		return 1
	fi

	echo "==> Boost dependency found after installation"
}

check_dependencies() {
	check_boost_dependency
}
