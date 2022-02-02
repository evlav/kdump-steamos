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
	logger "kdump-steamos: /etc/default/kdump not present - aborting..."
	exit 0
fi

. /etc/default/kdump

KDUMP_MAIN_FOLDER="$(cat "${KDUMP_MNT}")"
rm -f "${KDUMP_MNT}"

if [ ! -d "${KDUMP_MAIN_FOLDER}" ]; then
	logger "kdump-steamos: invalid folder (${KDUMP_MAIN_FOLDER}) - aborting..."
	exit 0
fi

LOGS_FOUND=0
KDUMP_LOGS_FOLDER="${KDUMP_MAIN_FOLDER}/logs"

# Use UTC timezone to match kdump collection
CURRENT_TSTAMP=$(date -u +"%Y%m%d%H%M")
CURRENT_EPOCH=$(date +"%s")

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
	mv "${PSTORE_FOLDER}"/* "${KDUMP_LOGS_FOLDER}/" 2>/dev/null

#  Enter the else block in case we don't have pstore logs - maybe we
#  have kdump logs then.
else
	KDUMP_CRASH_FOLDER="${KDUMP_MAIN_FOLDER}/crash"
	KDUMP_CNT=$(find "${KDUMP_CRASH_FOLDER}"/* -type d 2>/dev/null | wc -l)

	if [ "${KDUMP_CNT}" -ne 0 ]; then
		#  Dump the kdump logs in the <...>/kdump/logs/kdump subfolder.
		KD_FOLDER="${KDUMP_LOGS_FOLDER}/kdump"
		mkdir -p "${KD_FOLDER}"

		LOOP_CNT=0
		while [ "${KDUMP_CNT}" -gt 0 ]; do
			CRASH_CURRENT=$(find "${KDUMP_CRASH_FOLDER}"/* -type d 2>/dev/null | head -n1)
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
		mv "${KD_FOLDER}"/* "${KDUMP_LOGS_FOLDER}/" 2>/dev/null
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
	STEAM_ID=0
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

			#  Get also the Steam ID, used in the POST request to Valve servers; this
			#  is a bit fragile, but there's no proper VDF parse tooling it seems...
			LN=$(grep -n "AccountName.*${STEAM_ACCOUNT}\"" "${LOGINVDF}" | cut -f1 -d:)
			LN=$((LN - 2))
			STEAM_ID=$(sed -n "${LN}p" "${LOGINVDF}" | cut -f2 -d\")
			break
		done
	fi

	#  Here we collect some more info, like DMI data, os-release, etc;
	#  TODO: Add Steam application / Proton / Games logs collection...
	dmidecode > "${KDUMP_LOGS_FOLDER}/dmidecode.${CURRENT_TSTAMP}"

	BUILD_FNAME="${KDUMP_LOGS_FOLDER}/build.${CURRENT_TSTAMP}"
	cp "/etc/os-release" "${BUILD_FNAME}"

	VERSION_FNAME="${KDUMP_LOGS_FOLDER}/version.${CURRENT_TSTAMP}"
	uname -r > "${VERSION_FNAME}"

	#  Before compressing the logs, save a crash summary
	CRASH_SUMMARY="${KDUMP_LOGS_FOLDER}/crash_summary.${CURRENT_TSTAMP}"
	SED_EXPR="/Kernel panic \-/,/Kernel Offset\:/p"
	sed -n "${SED_EXPR}" "${KDUMP_LOGS_FOLDER}"/dmesg* > "${CRASH_SUMMARY}"

	sync "${BUILD_FNAME}" "${VERSION_FNAME}" "${CRASH_SUMMARY}"

	#  Create the dump compressed pack.
	LOG_FNAME="steamos-${SN}-${STEAM_ACCOUNT}.${CURRENT_TSTAMP}.zip"
	LOG_FNAME="${KDUMP_MAIN_FOLDER}/${LOG_FNAME}"
	zip -9 -jq "${LOG_FNAME}" "${KDUMP_LOGS_FOLDER}"/* 1>/dev/null 2>&1

	sync "${LOG_FNAME}" 2>/dev/null
	if [ ! -s "${LOG_FNAME}" ]; then
		logger "kdump-steamos: couldn't create the log archive, aborting..."
		exit 0
	fi


	##############################
	#  Log submission mechanism  #
	##############################


	#  The POST request requires a valid Steam ID.
	if [ "${STEAM_ID}" -eq 0 ]; then
		logger "kdump-steamos: invalid Steam ID, cannot submit logs"
		exit 0
	fi

	#  Construct the POST request fields...
	REQ_DUMP_SZ="$(stat --printf="%s" "${LOG_FNAME}")"
	REQ_PRODUCT="holo"
	REQ_BUILD="$(grep "BUILD_ID" "${BUILD_FNAME}" | cut -f2 -d=)"
	REQ_VER="$(cat "${VERSION_FNAME}")"
	REQ_PLATFORM="linux"
	REQ_TIME="${CURRENT_EPOCH}"
	STACK_SED_EXPR="/ Call Trace\:/,/ RIP\:/p"
	REQ_STACK="$(sed -n "${STACK_SED_EXPR}" "${CRASH_SUMMARY}" | sed "1d")"
	REQ_NOTE="$(cat "${CRASH_SUMMARY}")"

	POST_REQ="steamid=${STEAM_ID}&have_dump_file=1&dump_file_size=${REQ_DUMP_SZ}&product=${REQ_PRODUCT}&build=${REQ_BUILD}"
	POST_REQ="${POST_REQ}&version=${REQ_VER}&platform=${REQ_PLATFORM}&crash_time=${REQ_TIME}&stack=${REQ_STACK}&note=${REQ_NOTE}&format=json"

	#  Now we can safely delete this folder.
	rm -rf  "${KDUMP_LOGS_FOLDER}"

	# Network validation before log submission
	LOOP_CNT=0
	MAX_LOOP=99
	TEST_URL="steampowered.com"

	while [ ${LOOP_CNT} -lt ${MAX_LOOP} ]; do
		if ping -i 0.5 -w 2 -c 2 "${TEST_URL}" 1>/dev/null 2>&1; then
			break
		fi
		LOOP_CNT=$((LOOP_CNT + 1))
		sleep 1
	done

	# Bail out in case we have network issues
	if [ ${LOOP_CNT} -ge ${MAX_LOOP} ]; then
		logger "kdump-steamos: network issue - cannot send logs"
		exit 0
	fi

	CURL_ERR="${KDUMP_MAIN_FOLDER}/.curl_err"
	START_URL="$(echo "${POST_URL}" | sed 's/ACTION/Start/g')"
	FINISH_URL="$(echo "${POST_URL}" | sed 's/ACTION/Finish/g')"
	RESPONSE_FILE="${KDUMP_MAIN_FOLDER}/.curl_response"

	if ! curl -X POST -d "${POST_REQ}" "${START_URL}" 1>"${RESPONSE_FILE}" 2>"${CURL_ERR}"; then
		logger "kdump-steamos: curl issues - failed in the log submission POST (err=$?)"
		#rm -f "${RESPONSE_FILE}" #  keep this for now, as debug information
		exit 0
	fi

	RESPONSE_PUT_URL="$(jq -r '.response.url' "${RESPONSE_FILE}")"
	RESPONSE_GID="$(jq -r '.response.gid' "${RESPONSE_FILE}")"

	# Construct the PUT request based on the POST response
	CURL_PUT_HEADERS="${KDUMP_MAIN_FOLDER}/.curl_put_headers"
	PUT_HEADERS_LEN=$(jq '.response.headers.pairs | length' "${RESPONSE_FILE}")

	# Validate the response headers; allow a maximum of 20 arguments for now...
	if [ "${PUT_HEADERS_LEN}" -le 0 ] || [ "${PUT_HEADERS_LEN}" -gt 20 ]; then
		logger "kdump-steamos: unsupported number of response headers (${PUT_HEADERS_LEN}), aborting..."
		#rm -f "${RESPONSE_FILE}" #  keep this for now, as debug information
		exit 0
	fi

	LOOP_CNT=0
	while [ ${LOOP_CNT} -lt "${PUT_HEADERS_LEN}" ]; do
		NAME="$(jq -r ".response.headers.pairs[${LOOP_CNT}].name" "${RESPONSE_FILE}")"
		VAL="$(jq -r ".response.headers.pairs[${LOOP_CNT}].value" "${RESPONSE_FILE}")"

		echo "${NAME}: ${VAL}" >> "${CURL_PUT_HEADERS}"
		LOOP_CNT=$((LOOP_CNT + 1))
	done

	rm -f "${RESPONSE_FILE}"
	if ! curl -X PUT --data-binary "@${LOG_FNAME}" -H "@${CURL_PUT_HEADERS}" "${RESPONSE_PUT_URL}" 1>/dev/null 2>"${CURL_ERR}"; then
		logger "kdump-steamos: curl issues - failed in the log submission PUT (err=$?)"
		#rm -f "${CURL_PUT_HEADERS}" #  keep this for now, as debug information
		exit 0
	fi

	rm -f "${CURL_PUT_HEADERS}"
	if ! curl -X POST -d "gid=${RESPONSE_GID}" "${FINISH_URL}" 1>/dev/null 2>"${CURL_ERR}"; then
		logger "kdump-steamos: curl issues - failed in the log finish POST (err=$?)"
		exit 0
	fi

	#  If we reached this point, the zipped log should have been submitted
	#  succesfully; save a local copy as well.
	#  TODO: implement a clean-up routine to just keep up to N logs...

	rm -f "${CURL_ERR}"
	SENT_FLD="${KDUMP_MAIN_FOLDER}/sent_logs/"
	mkdir -p "${SENT_FLD}"

	mv "${LOG_FNAME}" "${SENT_FLD}"
	logger "kdump-steamos: successfully submitted crash log to Valve"
fi
