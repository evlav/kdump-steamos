#!/bin/bash
#
#  SPDX-License-Identifier: LGPL-2.1+
#
#  Copyright (c) 2022 Valve.
#
#  This is the systemd loader for the SteamOS kdump log submitter;
#  it's invoked by systemd, basically it just loads a detached
#  process and exits successfuly, in order to prevent boot hangs.

/usr/lib/kdump/submit-report.sh & disown
exit 0
