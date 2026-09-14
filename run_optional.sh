#!/bin/bash

run_optional() {
	if "$@"; then
		return 0
	fi
	echo "warning: command failed: $*" >&2
	return 0
}