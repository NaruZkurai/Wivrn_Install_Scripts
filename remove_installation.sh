#!/bin/bash

remove_installation() {
	local prefix="${1%/}"
	local relative_path
	local paths=(
		lib/systemd/user/wivrn.service
		lib/firewalld/services/wivrn.xml
		lib/environment.d/wivrn.conf
		bin/wivrn-server
		bin/wivrn-dashboard
		bin/wivrnctl
		share/openxr/1/openxr_wivrn.json
		lib/wivrn/libopenxr_wivrn.so
		lib/wivrn/libmonado_wivrn.so.0.0.0
		lib/wivrn/libmonado_wivrn.so.25
		lib/wivrn/libmonado_wivrn.so
		share/metainfo/io.github.wivrn.wivrn.metainfo.xml
		share/icons/hicolor/scalable/apps/io.github.wivrn.wivrn.svg
		share/applications/io.github.wivrn.wivrn.desktop
		share/bash-completion/completions/wivrnctl
		share/zsh/site-functions/_wivrnctl
	)

	for relative_path in "${paths[@]}"; do
		if [[ -e "${prefix}/${relative_path}" ]]; then
			echo "==> removing ${prefix}/${relative_path}"
			rm -f "${prefix}/${relative_path}"
		fi
	done

	rm -rf "${prefix}/lib/wivrn"
	find "${prefix}/share/locale" -type f -name 'wivrn-dashboard.mo' -delete 2>/dev/null || true
}
