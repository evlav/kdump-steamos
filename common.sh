
#  This function has the purpose of loading the necessary external
#  variables, in the form of one (or more) configuration file(s). If the
#  procedure fails, we must abort - otherwise it'll fail in a later stage.
load_kdump_config() {
	HAVE_CFG_FILES=0
	shopt -s nullglob
	for cfg in "/usr/share/kdump.d"/*; do
		if [ -f "$cfg" ]; then
			. "$cfg"
			HAVE_CFG_FILES=1
		fi
	done
	shopt -u nullglob

	if [ ${HAVE_CFG_FILES} -eq 0 ]; then
		logger "kdump: no config files in /usr/share/kdump.d/ - aborting."
		exit 1
	fi
}

