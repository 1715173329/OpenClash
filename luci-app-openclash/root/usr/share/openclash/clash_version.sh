#!/bin/sh
. /usr/share/openclash/openclash_functions.sh

CKTIME="$(date "+%Y-%m-%d-%H")"
LAST_OPVER="/tmp/clash_last_version"

config_load "$_CFG_NAME"
config_get_oc RELEASE_BRANCH "release_branch" "master"

SET_LOCK "884" "_clash_version"

if [ "$CKTIME" != "$(awk -F 'CheckTime: ' '{print $2}' "$LAST_OPVER" 2>"/dev/null" | xargs)" ]; then
	if pidof clash >"/dev/null"; then
		CURL_GET_SMALL_FILE "https://raw.githubusercontent.com/vernesong/OpenClash/$RELEASE_BRANCH/core_version" -o "$LAST_OPVER"
	fi

	if [ "$?" -ne "0" ] || ! pidof clash >"/dev/null"; then
		CURL_GET_SMALL_FILE "https://cdn.jsdelivr.net/gh/vernesong/OpenClash@$RELEASE_BRANCH/core_version" -o "$LAST_OPVER"
	fi

	if [ "$?" -eq "0" ] && [ -s "$LAST_OPVER" ]; then
		echo -e "CheckTime: $CKTIME" >> "$LAST_OPVER"
	else
		rm -rf "$LAST_OPVER"
	fi
fi

DEL_LOCK "884" "_clash_version"
