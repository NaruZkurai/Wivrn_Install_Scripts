#!/bin/bash

setup_wivrn_service() {
	if command -v systemctl >/dev/null 2>&1; then
		run_optional systemctl --user daemon-reload
		run_optional systemctl --user enable --now wivrn.service
	else
		echo "warning: systemctl is unavailable; skipping WiVRn service setup" >&2
	fi
}
