#!/bin/bash

setup_avahi() {
	if command -v systemctl >/dev/null 2>&1; then
		if systemctl list-unit-files avahi-daemon.service >/dev/null 2>&1; then
			run_optional "${HOST_SUDO[@]}" systemctl enable --now avahi-daemon
		else
			echo "warning: avahi-daemon.service is not installed; skipping Avahi setup" >&2
		fi
	else
		echo "warning: systemctl is unavailable; skipping Avahi setup" >&2
	fi
}