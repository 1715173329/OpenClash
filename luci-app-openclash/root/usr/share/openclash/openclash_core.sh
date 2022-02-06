#!/bin/sh
. /usr/share/openclash/openclash_functions.sh

CORE_TYPE="$1"
{ [ -z "$CORE_TYPE" ] || [ "$CORE_TYPE" = "one_key_update" ]; } && CORE_TYPE="Dev"

config_load "$_CFG_NAME"
config_get_oc C_CORE_TYPE "core_type"
config_get_oc CPU_MODEL "core_version" "0"
config_get_oc RELEASE_BRANCH "release_branch" "master"
config_get_oc small_flash_memory

CORE_LV_PATH="/tmp/clash_last_version"
[ ! -f "$CORE_LV_PATH" ] && $_RES_PATH/clash_version.sh 2>"/dev/null"
if [ ! -f "$CORE_LV_PATH" ]; then
	LOG_OUT "[$CORE_TYPE] Error: Failed to check core version, please try again later."
	sleep 3
	LOG_CLEAN

	exit 0
fi

[ "$small_flash_memory" -ne "1" ] || DIR_PREFIX="/tmp"
core_path="${DIR_PREFIX}${_CFG_PATH}/core"
mkdir -p "$core_path"
dev_core_path="$core_path/clash"
tun_core_path="$core_path/clash_tun"

tmp_dev_core_path="/tmp/clash.tar.gz"
tmp_tun_core_path="/tmp/clash_tun.gz"
tmp_tun_core="/tmp/clash_tun"

case "$CORE_TYPE" in
"TUN")
	CORE_CV="$($tun_core_path -v 2>"/dev/null" | awk -F ' ' '{print $2}')"
	CORE_LV="$(sed -n 2p "$CORE_LV_PATH" 2>"/dev/null")"
	if [ -z "$CORE_LV" ]; then
		LOG_OUT "Error: [$CORE_TYPE] Failed to check core version, please try again later."
		sleep 3
		LOG_CLEAN

		exit 0
	fi
	;;
*)
	CORE_CV="$($dev_core_path -v 2>"/dev/null" |awk -F ' ' '{print $2}')"
	CORE_LV="$(sed -n 1p "$CORE_LV_PATH" 2>"/dev/null")"
	;;
esac
   
{ [ "$C_CORE_TYPE" = "$CORE_TYPE" ] || [ -z "$C_CORE_TYPE" ]; } && NEED_RESTART=1
{ [ -n "$2" ] || [ "$1" = "one_key_update" ]; } && NEED_RESTART=0

if [ "$CORE_CV" != "$CORE_LV" ] || [ -z "$CORE_CV" ]; then
	if [ "$CPU_MODEL" != "0" ]; then
		LOG_OUT "[$CORE_TYPE] Downloading core..."

		if [ "$RELEASE_BRANCH" = "dev" ]; then
			case "$CORE_TYPE" in
			"TUN")
				CURL_GET_CORE "$_REPO_URL_RAW_PREFIX/$RELEASE_BRANCH/core-lateset/premium/clash-$CPU_MODEL-$CORE_LV.gz" -o "$tmp_tun_core_path"
				;;
			*)
				CURL_GET_CORE "$_REPO_URL_RAW_PREFIX/$RELEASE_BRANCH/core-lateset/dev/clash-$CPU_MODEL.tar.gz" -o "$tmp_dev_core_path"
				;;
			esac
		else
			if IS_CLASH_RUNNING; then
				case "$CORE_TYPE" in
				"TUN")
					CURL_GET_CORE "$_REPO_URL_PREFIX/releases/download/TUN-Premium/clash-$CPU_MODEL-$CORE_LV.gz" -o "$tmp_tun_core_path"
					;;
				*)
					CURL_GET_CORE "$_REPO_URL_PREFIX/releases/download/Clash/clash-$CPU_MODEL.tar.gz" -o "$tmp_dev_core_path"
					;;
				esac
			fi
		fi

		if [ "$?" -ne "0" ] || ! IS_CLASH_RUNNING; then
			case $CORE_TYPE in
			"TUN")
				CURL_GET_CORE "https://cdn.jsdelivr.net/gh/$_REPO_NAME@$RELEASE_BRANCH/core-lateset/premium/clash-$CPU_MODEL-$CORE_LV.gz" -o "$tmp_tun_core_path"
				;;
			*)
				CURL_GET_CORE "https://cdn.jsdelivr.net/gh/$_REPO_NAME@$RELEASE_BRANCH/core-lateset/dev/clash-$CPU_MODEL.tar.gz" -o "$tmp_dev_core_path"
				;;
			esac
		fi
      
		if [ "$?" -eq "0" ]; then
			LOG_OUT "[$CORE_TYPE] Succeeded in downloading core, replacing the old one..."
			case "$CORE_TYPE" in
			"TUN")
				[ -s "$tmp_tun_core_path" ] && {
					gzip -d "$tmp_tun_core_path"
					rm -f "$tun_core_path" "$tmp_tun_core_path"
					chmod 4755 "$tmp_tun_core"
				}
				;;
			*)
				[ -s "$tmp_tun_core_path" ] && {
					rm -f "$dev_core_path"
					tar -zxf "$tmp_dev_core_path" -C "$core_path"
					rm -f "$tmp_dev_core_path"
					chmod 4755 "$dev_core_path"
				}
				;;
			esac

			if [ "$?" -ne "0" ]; then
				[ "$CORE_TYPE" != "TUN" ] || rm -rf "$tmp_tun_core"

				LOG_OUT "[$CORE_TYPE] Failed to update core, please check your network and try again later!"
				sleep 3
				LOG_CLEAN

				exit 0
			fi
      
			[ "$NEED_RESTART" -ne "1" ] || killall -q -9 clash

			[ "$CORE_TYPE" != "TUN" ] || mv -f "$tmp_tun_core" "$tun_core_path"

			if [ "$?" -eq "0" ]; then
				LOG_OUT "[$CORE_TYPE] Core is updated successfully!"
				sleep 3

				if [ -n "$2" ] || [ "$1" = "one_key_update" ]; then
					uci set "$_CFG_NAME.config.config_reload"="0"
					uci commit "$_CFG_NAME"
				fi

				if [ "$NEED_RESTART" -eq 1 ] && ! IS_INIT_RUNNING; then
					/etc/init.d/$_GLOBAL_NAME restart
				fi

				LOG_CLEAN
			else
				[ "$CORE_TYPE" != "TUN" ] || rm -rf "$tmp_tun_core"

				LOG_OUT "[$CORE_TYPE] Failed to update core. Please make sure there's enough flash memory space and try again."
				sleep 3
				LOG_CLEAN
			fi
		else
			rm -rf "${tmp_tun_core%_*}" "$tmp_tun_core"

			LOG_OUT "[$CORE_TYPE] Failed to download core. Please check your network and try again later."
			sleep 3
			LOG_CLEAN
		fi
	else
		LOG_OUT "[$CORE_TYPE] Error: core architecture is not specified. Please set it in \"Global Settings\" and try again!"
		sleep 3
		LOG_CLEAN
	fi
else
	LOG_OUT "[$CORE_TYPE] Core is up-to-date."
	sleep 3
	LOG_CLEAN
fi
