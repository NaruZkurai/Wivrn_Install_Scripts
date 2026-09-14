#!/bin/bash
setup_firewall() {
	if command -v firewall-cmd >/dev/null 2>&1; then
		run_optional "${HOST_SUDO[@]}" firewall-cmd --permanent --add-port=9757/tcp
		run_optional "${HOST_SUDO[@]}" firewall-cmd --permanent --add-port=9757/udp
		run_optional "${HOST_SUDO[@]}" firewall-cmd --permanent --add-port=5353/udp
		run_optional "${HOST_SUDO[@]}" firewall-cmd --reload
	elif command -v ufw >/dev/null 2>&1; then
		run_optional "${HOST_SUDO[@]}" ufw allow 9757/tcp
		run_optional "${HOST_SUDO[@]}" ufw allow 9757/udp
		run_optional "${HOST_SUDO[@]}" ufw allow 5353/udp
	else
		echo "warning: firewall tool not found; skipping firewall setup" >&2
	fi
}
