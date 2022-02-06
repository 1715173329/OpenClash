#!/bin/sh
. /usr/share/openclash/openclash_functions.sh

# 一键更新
if [ "$1" = "one_key_update" ]; then
	uci set "$_CFG_NAME.config.enable"="1"
	uci commit "$_CFG_NAME"
	$_RES_PATH/${_GLOBAL_NAME}_core.sh "$1" >"/dev/null" 2>&1 &
	$_RES_PATH/${_GLOBAL_NAME}_core.sh "TUN" "$1" >"/dev/null" 2>&1 &
	wait
fi

LAST_OPVER="/tmp/${_GLOBAL_NAME}_last_version"
LAST_VER="$(sed -n 1p "$LAST_OPVER" 2>"/dev/null" | sed "s/^v//g" | tr -d "\n")"
OP_CV="$(sed -n 1p "$_RES_PATH/res/openclash_version" 2>"/dev/null" | awk -F '-' '{print $1}' | awk -F 'v' '{print $2}' | awk -F '.' '{print $2$3}')"
OP_LV="$(sed -n 1p "$LAST_OPVER" 2>"/dev/null" | awk -F '-' '{print $1}' | awk -F 'v' '{print $2}' | awk -F '.' '{print $2$3}')"

config_load "$_CFG_NAME"
config_get_oc RELEASE_BRANCH "release_branch" "master"
config_get_oc_bool RELOAD_CONFIG "config_reload"

SET_LOCK "878" "_update"

TMP_OC_FILE="/tmp/openclash.ipk"
if [ -f "$LAST_OPVER" ] && [ "$OP_LV" -gt "$OP_CV" ]; then
	LOG_OUT "Downloading [OpenClash - v$LAST_VER]..."
	if [ "$RELEASE_BRANCH" = "dev" ]; then
		CURL_GET_CORE "$_REPO_URL_RAW_PREFIX/$RELEASE_BRANCH/luci-app-openclash_${LAST_VER}_all.ipk" -o "$TMP_OC_FILE"
	else
		! IS_CLASH_RUNNING || CURL_GET_CORE "$_REPO_URL_PREFIX/releases/download/v$LAST_VER/luci-app-openclash_${LAST_VER}_all.ipk" -o "$TMP_OC_FILE"
	fi

	if [ "$?" -ne "0" ] || ! IS_CLASH_RUNNING; then
		CURL_GET_CORE "https://cdn.jsdelivr.net/gh/$_REPO_NAME@$RELEASE_BRANCH/luci-app-openclash_${LAST_VER}_all.ipk" -o "$TMP_OC_FILE"
	fi
   
	if [ "$?" -eq "0" ] && [ -s "$TMP_OC_FILE" ]; then
		LOG_OUT "[OpenClash - v$LAST_VER] is downloaded successfully, start pre-update testing..."
		
		if ! opkg install --noaction "$TMP_OC_FILE" >> "$LOG_FILE" 2>&1; then
			LOG_OUT "[OpenClash - v$LAST_VER] Pre-update testing is failed. The file is saved in \"/tmp/opencrash.ipk\". Please try to update me manually!"
			sleep 3
			LOG_CLEAN

			DEL_LOCK "878" "_update"
			exit 0
		fi

		LOG_OUT "[OpenClash - v$LAST_VER] Pre-update testing is passed. Ready to update and please do not refresh the page or do any other operations!"
		cat > "/tmp/openclash_update.sh" <<-EOF
		#!/bin/sh
		START_LOG="$START_LOG"
		LOG_FILE="$LOG_FILE"
		LOGTIME="\$(date "+%Y-%m-%d %H:%M:%S")"
				
		LOG_OUT()
		{
			if [ -n "\$1" ]; then
				echo -e "\$1" > "\$START_LOG"
				echo -e "\$LOGTIME \$1" >> "\$LOG_FILE"
			fi
		}

		LOG_CLEAN()
		{
			echo "" > "\$START_LOG"
		}

		uci set $_CFG_NAME.config.enable=0
		uci commit $_CFG_NAME
		LOG_OUT "Uninstalling the old version. Please do not refresh the page or do any other operations!"
		opkg remove --force-depends --force-remove luci-app-openclash

		LOG_OUT "Installing the new version. Please do not refresh the page or do any other operations!"
		if opkg install "$TMP_OC_FILE"; then
			rm -f "$TMP_OC_FILE"
			LOG_OUT "OpenClash is update successfully. Restart service..."
			sleep 3

			uci set $_CFG_NAME.config.enable=1
			uci commit $_CFG_NAME

			/etc/init.d/$_GLOBAL_NAME restart 2>"/dev/null"
		else
			LOG_OUT "Failed to update OpenClash. The file is saved in \"/tmp/opencrash.ipk\". Please try to update me manually!"
			sleep 3
			LOG_CLEAN
		fi
		EOF

		chmod 4755 "/tmp/openclash_update.sh"
		nohup "/tmp/openclash_update.sh" &
		wait
		rm -f "/tmp/openclash_update.sh"
	else
		rm -rf "$TMP_OC_FILE"

		LOG_OUT "[OpenClash - v$LAST_VER] Failed to download. Please check your network and try again later."
		sleep 3
		LOG_CLEAN

		RELOAD_CHECK=1
		if [ "$(uci get openclash.config.config_reload 2>"/dev/null")" -eq 0 ]; then
			uci set openclash.config.config_reload=1
			uci commit openclash
			/etc/init.d/openclash restart 2>"/dev/null"
		fi
	fi
else
	if [ ! -f "$LAST_OPVER" ]; then
		LOG_OUT "Failed to get the latest version. Please try again later..."
		sleep 3
		LOG_CLEAN
   else
		LOG_OUT "OpenClash is up-to-date."
		sleep 3
		LOG_CLEAN
	fi

	RELOAD_CHECK=1
fi

[ -z "$RELOAD_CHECK" ] || {
	if [ "$RELOAD_CONFIG" -eq "0" ]; then
		uci set "$_CFG_NAME.config.config_reload"="1"
		uci commit "$_CFG_NAME"
		/etc/init.d/"$_GLOBAL_NAME" restart 2>"/dev/null"
	fi
}

DEL_LOCK "878" "_update"
