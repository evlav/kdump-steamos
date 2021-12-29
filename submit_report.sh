#!/bin/sh
#
#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#
#  This is currently a dummy script for kdump, but collects and clears
#  pstore saved logs for now. It aims, in the future, to submit error/crash
#  reports to Valve servers in order to do a post-mortem analysis.
#  This is part of SteamOS kdump - it is invoked by systemd on boot time
#  and should always exit graciously to avoid breaking the boot services.
#

if [ ! -f "/etc/default/kdump" ]; then
	exit 0
fi

. /etc/default/kdump

#  Yeah, we assume pstore is mounted by default, in this location;
#  if not, we get a 0 and don't loop.
PSTORE_CNT=$(find /sys/fs/pstore/* 2>/dev/null | grep -c ramoops)
if [ ${PSTORE_CNT} -eq 0 ]; then
	exit 0
fi

#  We do some validation to be sure KDUMP_MNT pointed path is valid...
KDUMP_CRASH_FOLDER="$(cat ${KDUMP_MNT})"
rm -f ${KDUMP_MNT}

if [ ! -d "${KDUMP_CRASH_FOLDER}" ]; then
	exit 0
fi

#  If valid, then dump the pstore logs in the crash subfolder.
KDUMP_CRASH_FOLDER="${KDUMP_CRASH_FOLDER}/crash"
mkdir -p ${KDUMP_CRASH_FOLDER}

PSTORE_TSTAMP=$(date +"%Y%m%d%H%M")
LOOP_CNT=0
while [ ${PSTORE_CNT} -gt 0 ];
do
	PSTORE_FILE="$(find /sys/fs/pstore/* | grep ramoops | sort | head -n1)"
	SAVED_FILE="${KDUMP_CRASH_FOLDER}/dmesg-pstore.${PSTORE_TSTAMP}-${LOOP_CNT}"

	cat ${PSTORE_FILE} > ${SAVED_FILE}
	sync ${SAVED_FILE}
	rm -f ${PSTORE_FILE}

	PSTORE_CNT=$((${PSTORE_CNT} - 1))
	LOOP_CNT=$((${LOOP_CNT} + 1))
done
exit 0
