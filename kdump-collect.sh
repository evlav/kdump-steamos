#!/bin/sh
#
#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#  Maintainer: Guilherme G. Piccoli <gpiccoli@igalia.com>
#
#  Script for effectively collecting the core dump/dmesg from
#  within a minimal initrd - part of kdump/pstore tooling.
#  The most fail-prone operations are guarded with conditionals to
#  bail in case we indeed fail - worst thing here would be to have
#  a bad condition and get stuck in this minimal initrd with no
#  output for the user.
#

#  We have a more controlled situation with regards the config
#  files here, since we manually added them in the initrd and
#  the validation also happened there, during such addition,
#  hence not requiring checking here.
for cfg in "/usr/lib/kdump/conf/"/*; do
	. "$cfg"
done

VMCORE="/proc/vmcore"
KDUMP_TIMESTAMP=$(date -u +"%Y%m%d%H%M")
KDUMP_FOLDER="/kdump_path/${KDUMP_FOLDER}/crash/${KDUMP_TIMESTAMP}"

#  Bail out in case we don't have a vmcore, i.e. either we're not kdumping
#  or something is pretty wrong and we wouldn't be able to progress.
#
if [ ! -f $VMCORE ]; then
	reboot -f
fi

DEVN="$(cat /usr/lib/kdump/kdump.devnode)"
mkdir -p "/kdump_path"

if ! mount "${DEVN}" /kdump_path; then
	reboot -f
fi

mkdir -p "${KDUMP_FOLDER}"

#  we want to split on spaces, it's a set of parameters!
#  shellcheck disable=SC2086
/usr/bin/makedumpfile ${MAKEDUMPFILE_DMESG_CMD} $VMCORE "${KDUMP_FOLDER}/dmesg.txt"
sync "${KDUMP_FOLDER}/dmesg.txt"

if [ "${FULL_COREDUMP}" -ne 0 ]; then
	#  shellcheck disable=SC2086
	/usr/bin/makedumpfile ${MAKEDUMPFILE_COREDUMP_CMD} $VMCORE "${KDUMP_FOLDER}/vmcore.compressed"
	sync "${KDUMP_FOLDER}/vmcore.compressed"
fi

umount "${DEVN}"
sync

reboot -f
