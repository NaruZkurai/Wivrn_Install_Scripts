#!/bin/bash

setup_wivrn_service() {
	if command -v systemctl >/dev/null 2>&1; then
		local service_file="${PREFIX}/lib/systemd/user/wivrn.service"
		if [[ -f "$service_file" ]]; then
			run_optional systemctl --user link "$service_file"
		fi
		run_optional systemctl --user daemon-reload
		run_optional systemctl --user enable --now wivrn.service
	else
		echo "warning: systemctl is unavailable; skipping WiVRn service setup" >&2
	fi
}
