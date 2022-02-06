#!/bin/bash

# ===== GENERIC UTILITIES ===== #

. /lib/functions.sh

_CFG_NAME="openclash"
_GLOBAL_NAME="openclash"

_CFG_PATH="/etc/$_CFG_NAME"
_RES_PATH="/usr/share/$_GLOBAL_NAME"

_REPO_NAME="vernesong/OpenClash"
_REPO_URL_PREFIX="https://github.com/$_REPO_NAME"
_REPO_URL_RAW_PREFIX="https://raw.githubusercontent.com/$_REPO_NAME"

# ===== CURL ===== #

CURL_SILENT() {
	curl "$@" >"/dev/null" 2>&1
}

CURL_GET_CORE(){
	CURL_SILENT -sL --max-time 10 --retry 2 "$@"
}

CURL_GET_FILE(){
	CURL_SILENT -sL --connect-timeout 10 --retry 2 "$@"
}

CURL_GET_SMALL_FILE(){
	CURL_SILENT -sL --connect-timeout 5 --retry 2 "$@"
}

CURL_GET_SUB(){
	CURL_GET_FILE -H "User-Agent: Clash" "$@"
}


# ===== LOCK ===== #

SET_LOCK() {
   exec "$1">"/tmp/lock/${_GLOBAL_NAME}${2}.lock" 2>"/dev/null"
   flock -x "$1" 2>"/dev/null"
}

DEL_LOCK() {
   flock -u "$1" 2>"/dev/null"
   rm -f "/tmp/lock/${_GLOBAL_NAME}${2}.lock"
}


# ===== LOG ===== #

START_LOG="/tmp/${_GLOBAL_NAME}_start.log"
LOG_FILE="/tmp/${_GLOBAL_NAME}.log"

LOG_ALERT() {
	echo -e "$(tail -n 20 "$LOG_FILE" | grep 'level=fatal' | awk 'END {print}')" > "$START_LOG"
	sleep 3
}

LOG_CLEAN() {
	echo > "$START_LOG"
}

LOG_OUT() {
	[ -n "$*" ] && {
		echo -e "$*" > $START_LOG
		echo -e "$(date "+%Y-%m-%d %H:%M:%S") $1" >> "$LOG_FILE"
	}
}


# ===== PS ===== #

_PS="/bin/busybox ps -w"

PS_CFGNAME() {
	{ $_PS  | grep "/etc/$_CFG_NAME/clash" | grep -v "grep" | awk -F '-f ' '{print $2}'; } 2>"/dev/null"
}

PS_PIDS() {
	$_PS | grep "$1" | grep -v "grep" | awk '{print $1}' 2>"/dev/null"
}

PS_STAT(){
	$_PS | grep -v "grep" | grep -c "$1"
}

IS_CLASH_RUNNING() {
	# RUNNING: 0 / NOT RUNNING: 1
	if pidof "clash" >"/dev/null"; then
		return 0
	else
		return 1
	fi
}

IS_INIT_RUNNING() {
	# RUNNING: 0 / NOT RUNNING: 1
	if $_PS | grep -v "grep" | grep -c "/etc/init.d/$_GLOBAL_NAME" > "/dev/null"; then
		return 0
	else
		return 1
	fi
}


# ===== UCI HELPER =====

config_get_oc(){
	config_get "$1" "config" "${2:-$1}" $3
}

config_get_oc_bool(){
	config_get_bool "$1" "config" "${2:-$1}" $3
}
diff --git a/luci-app-openclash/root/usr/share/openclash/clash_version.sh b/luci-app-openclash/root/usr/share/openclash/clash_version.sh
