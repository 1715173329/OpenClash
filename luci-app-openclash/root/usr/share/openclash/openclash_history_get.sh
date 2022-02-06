#!/bin/sh
. /etc/openwrt_release
. /usr/share/openclash/openclash_functions.sh

config_load "$_CFG_NAME"

if [ "$1" = "close_all_conection" ]; then
	local SECRET PORT LAN_IP
	config_get_oc SECRET "dashboard_password"
	config_get_oc PORT cn_port
	LAN_IP=$(uci -q get network.lan.ipaddr | awk -F '/' '{print $1}' || ip addr show | grep -w 'inet' | grep 'global' | grep 'brd' | grep -Eo 'inet [0-9\.]+' | awk '{print $2}' | head -n 1)
	CURL_SILENT -m 2 -H "Authorization: Bearer ${SECRET}" -H "Content-Type:application/json" -X DELETE "http://$LAN_IP:$PORT/connections"
	exit 0
fi

config_get_oc core_version "" "0"
config_get_oc small_flash_memory

CONFIG_FILE="$(PS_CFGNAME)"
CONFIG_NAME=$(echo "$CONFIG_FILE" | awk -F '/' '{print $4}')
HISTORY_PATH_OLD="$_CFG_PATH/history/${CONFIG_NAME%.*}"
HISTORY_PATH="$_CFG_PATH/history/${CONFIG_NAME%.*}.db"
CACHE_PATH_OLD="$_CFG_PATH/.cache"

SET_LOCK "881" "_history_get"

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
	config_get_oc CONFIG_FILE "config_path"
	CONFIG_NAME="$(echo "$CONFIG_FILE" |awk -F '/' '{print $5}')"
	HISTORY_PATH_OLD="$_CFG_PATH/history/${CONFIG_NAME%.*}"
	HISTORY_PATH="$_CFG_PATH/history/${CONFIG_NAME%.*}.db"
fi

if IS_CLASH_RUNNING && [ -f "$CONFIG_FILE" ]; then
	if [ "$small_flash_memory" -eq "1" ] || echo "$core_version" | grep -q "mips" || echo "$DISTRIB_ARCH" | grep -q "mips"; then
		CACHE_PATH="/tmp${_CFG_PATH}/cache.db"
		if [ -f "$CACHE_PATH" ]; then
			cmp -s "$CACHE_PATH" "$HISTORY_PATH" || cp -f "$CACHE_PATH" "$HISTORY_PATH" 2>"/dev/null"
		fi
	fi

	if [ -f "$CACHE_PATH_OLD" ]; then
		cmp -s "$CACHE_PATH_OLD" "$HISTORY_PATH_OLD" || cp -f "$CACHE_PATH_OLD" "$HISTORY_PATH_OLD" 2>"/dev/null"
	fi
fi

DEL_LOCK "881" "_history_get"
