#!/bin/sh
#
#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2021 Valve.
#
#  This is the SteamOS kdump/pstore log collector and submitter; this script
#  prepares the pstore/kdump collected data and submit it to the services that
#  handle support at Valve. It considers pstore as a first alternative, if no
#  logs found (or if pstore is not mounted for some reason), tries to check
#  if kdump logs are present.
#

#  We do some validation to be sure KDUMP_MNT pointed path is valid...
#  That and having a valid /etc/default/kdump are essential conditions.
if [ ! -f "/etc/default/kdump" ]; then
	logger "/etc/default/kdump not present - aborting..." || true
	exit 0
fi

. /etc/default/kdump

KDUMP_MAIN_FOLDER="$(cat "${KDUMP_MNT}")"
rm -f "${KDUMP_MNT}"

if [ ! -d "${KDUMP_MAIN_FOLDER}" ]; then
	logger "invalid folder: ${KDUMP_MAIN_FOLDER} - aborting..." || true
	exit 0
fi

LOGS_FOUND=0
KDUMP_LOGS_FOLDER="${KDUMP_MAIN_FOLDER}/logs"

# Use UTC timezone to match kdump collection
CURRENT_TSTAMP=$(date -u +"%Y%m%d%H%M")

#  We assume pstore is mounted by default, in this location;
#  if not, we get a 0 and don't loop.
PSTORE_CNT=$(find /sys/fs/pstore/* 2>/dev/null | grep -c ramoops)
if [ "${PSTORE_CNT}" -ne 0 ]; then

	#  Dump the pstore logs in the <...>/kdump/logs/pstore subfolder.
	PSTORE_FOLDER="${KDUMP_LOGS_FOLDER}/pstore"
	mkdir -p "${PSTORE_FOLDER}"

	LOOP_CNT=0
	while [ "${PSTORE_CNT}" -gt 0 ]; do
		PSTORE_FILE="$(find /sys/fs/pstore/* | grep ramoops | sort | head -n1)"
		SAVED_FILE="${PSTORE_FOLDER}/dmesg-pstore.${CURRENT_TSTAMP}-${LOOP_CNT}"

		cat "${PSTORE_FILE}" > "${SAVED_FILE}"
		sync "${SAVED_FILE}"
		rm -f "${PSTORE_FILE}"

		PSTORE_CNT=$((PSTORE_CNT - 1))
		LOOP_CNT=$((LOOP_CNT + 1))
	done
	LOGS_FOUND=${LOOP_CNT}

	#  Logs should live on logs/ folder (no subfolders), due to the zip file
	mv ${PSTORE_FOLDER}/* "${KDUMP_LOGS_FOLDER}/" 2>/dev/null

#  Enter the else block in case we don't have pstore logs - maybe we
#  have kdump logs then.
else
	KDUMP_CRASH_FOLDER="${KDUMP_MAIN_FOLDER}/crash"
	KDUMP_CNT=$(find ${KDUMP_CRASH_FOLDER}/* -type d 2>/dev/null | wc -l)

	if [ "${KDUMP_CNT}" -ne 0 ]; then
		#  Dump the kdump logs in the <...>/kdump/logs/kdump subfolder.
		KD_FOLDER="${KDUMP_LOGS_FOLDER}/kdump"
		mkdir -p "${KD_FOLDER}"

		LOOP_CNT=0
		while [ "${KDUMP_CNT}" -gt 0 ]; do
			CRASH_CURRENT=$(find ${KDUMP_CRASH_FOLDER}/* -type d 2>/dev/null | head -n1)
			CRASH_TSTAMP=$(basename "${CRASH_CURRENT}")

			if [ -s "${CRASH_CURRENT}/dmesg.txt" ]; then
				SAVED_FILE="${KD_FOLDER}/dmesg-kdump.${CRASH_TSTAMP}"
				mv "${CRASH_CURRENT}/dmesg.txt" "${SAVED_FILE}"
				sync "${SAVED_FILE}"

			fi

			#  We don't care about submitting a vmcore, but let's save it if such file exists.
			if [ -s "${CRASH_CURRENT}/vmcore.compressed" ]; then
				SAVED_FILE="${KDUMP_CRASH_FOLDER}/vmcore.${CRASH_TSTAMP}"
				mv "${CRASH_CURRENT}/vmcore.compressed" "${SAVED_FILE}"
				sync "${SAVED_FILE}"

			fi

			rm -rf "${CRASH_CURRENT}"
			KDUMP_CNT=$((KDUMP_CNT - 1))
			LOOP_CNT=$((LOOP_CNT + 1))

		done
		LOGS_FOUND=$((LOGS_FOUND + LOOP_CNT))

		#  Logs should live on logs/ folder (no subfolders), due to the zip file
		mv ${KD_FOLDER}/* "${KDUMP_LOGS_FOLDER}/" 2>/dev/null
	fi

fi

# If we have pstore and/or kdump logs, let's process them in order to submit...
if [ ${LOGS_FOUND} -ne 0 ]; then

	PNAME="$(dmidecode -s system-product-name)"
	if [ "${PNAME}" = "Jupiter" ]; then
		SN="$(dmidecode -s system-serial-number)"
	else
		SN=0
	fi

	STEAM_ACCOUNT=0
	if [ -s "${LOGINVDF}" ]; then
		#  The following awk command was borrowed from:
		#  https://unix.stackexchange.com/a/663959
		NUMREG=$(grep -c AccountName "${LOGINVDF}")
		IDX=1
		while [ ${IDX} -le "${NUMREG}" ]; do
			MR=$(awk -v n=${IDX} -v RS='}' 'NR==n{gsub(/.*\{\n|\n$/,""); print}' "${LOGINVDF}" | grep "MostRecent" | cut -f4 -d\")
			if [ "$MR" -ne 1 ]; then
				IDX=$((IDX + 1))
				continue
			fi

			STEAM_ACCOUNT=$(awk -v n=${IDX} -v RS='}' 'NR==n{gsub(/.*\{\n|\n$/,""); print}' "${LOGINVDF}" | grep "AccountName" | cut -f4 -d\")
			break
		done
	fi

	#  Here we collect some more info, like DMI data, os-release, etc;
	#  ToDo: Add Steam application / Proton / Games logs collection...
	dmidecode > "${KDUMP_LOGS_FOLDER}/dmidecode.${CURRENT_TSTAMP}"
	grep "BUILD_ID" "/etc/os-release" | cut -f2 -d\= > "${KDUMP_LOGS_FOLDER}/build.${CURRENT_TSTAMP}"
	uname -r > "${KDUMP_LOGS_FOLDER}/version.${CURRENT_TSTAMP}"

	#  Create the dump compressed pack.
	LOG_FNAME="steamos-${SN}-${STEAM_ACCOUNT}.${CURRENT_TSTAMP}.zip"
	LOG_FNAME="${KDUMP_MAIN_FOLDER}/${LOG_FNAME}"

	zip -9 -jq "${LOG_FNAME}" ${KDUMP_LOGS_FOLDER}/* 1>/dev/null 2>&1
	sync "${LOG_FNAME}"
	rm -rf  "${KDUMP_LOGS_FOLDER}"

	#  TODO: implement a log submission mechanism, in order to send the zip file
	#  to Valve servers through an API.
fi
