#!/bin/bash
#
#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#  Maintainer: Guilherme G. Piccoli <gpiccoli@igalia.com>
#
#  Kdump-initrd module construction/inclusion script for
#  Dracut-based initramfs.
#

#  Only include kdump if it is explicitly asked in the argument list
check() {
	return 255
}

installkernel() {
	hostonly='' instmods ext4
}

install() {
	# A valid makedumpfile is essential for the kdump initrd creation.
	if [ ! -x "$(command -v makedumpfile)" ]; then
		logger "kdump: failed to create initrd, makedumpfile is missing"
		exit 1
	fi

	#  Load the necessary external variables, otherwise it'll fail later.
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

	#  First clear all unnecessary firmwares/drivers added by drm in order
	#  to reduce the size of the minimal initramfs being created. This
	#  should be already done via dracut cmdline arguments, but let's play
	#  safe and delete from here as well just in case.
	rm -rf "$initdir"/usr/lib/firmware/amdgpu/
	rm -rf "$initdir"/usr/lib/modules/*/kernel/drivers/gpu/drm/amd/*

	#  Install necessary binaries
	inst date
	inst sync
	inst makedumpfile

	mkdir -p "$initdir"/usr/share/kdump.d/
	cp -LR --preserve=all /usr/share/kdump.d/* "$initdir"/usr/share/kdump.d/

	#  Determine the numerical devnode for kdump, and save it on initrd;
	#  notice that partset link is not available that early in boot time.
	DEVN="$(readlink -f "${MOUNT_DEVNODE}")"
	echo "${DEVN}" > "$initdir"/usr/lib/kdump/kdump.devnode

	cp -LR --preserve=all /usr/lib/kdump/* "$initdir"/usr/lib/kdump/

	inst_hook pre-mount 01 "$moddir/kdump-collect.sh"
}
