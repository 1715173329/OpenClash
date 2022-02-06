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

SET_LOCK "878" "_update"

if [ "$(expr "$OP_LV" \> "$OP_CV")" -eq "1" ] && [ -f "$LAST_OPVER" ]; then
   LOG_OUT "Start Downloading【OpenClash - v$LAST_VER】..."
   if [ "$RELEASE_BRANCH" = "dev" ]; then
      CURL_GET_CORE "$_REPO_URL_RAW_PREFIX/$RELEASE_BRANCH/luci-app-openclash_$LAST_VER_all.ipk" -o /tmp/openclash.ipk
   else
      if pidof clash >"/dev/null"; then
         CURL_GET_CORE "$_REPO_URL_PREFIX/releases/download/v$LAST_VER/luci-app-openclash_$LAST_VER_all.ipk" -o /tmp/openclash.ipk
      fi
   fi
   
   if [ "$?" -ne "0" ] || ! pidof clash >"/dev/null"; then
      CURL_GET_CORE "https://cdn.jsdelivr.net/gh/$_REPO_NAME@$RELEASE_BRANCH/luci-app-openclash_$LAST_VER_all.ipk" -o /tmp/openclash.ipk
   fi
   
   if [ "$?" -eq "0" ] && [ -s "/tmp/openclash.ipk" ]; then
      LOG_OUT "【OpenClash - v$LAST_VER】Download Successful, Start Pre Update Test..."
      opkg install /tmp/openclash.ipk --noaction >>$LOG_FILE
      if [ "$?" -ne "0" ]; then
         LOG_OUT "【OpenClash - v$LAST_VER】Pre Update Test Failed, The File is Saved in /tmp/opencrash.ipk, Please Try to Update Manually!"
         sleep 3
         LOG_CLEAN
         DEL_LOCK "878" "_update"
         exit 0
      fi
      LOG_OUT "【OpenClash - v$LAST_VER】Pre Update Test Passed, Ready to Update and Please Do not Refresh The Page and Other Operations..."
      cat > /tmp/openclash_update.sh <<"EOF"
#!/bin/sh
START_LOG="/tmp/openclash_start.log"
LOG_FILE="/tmp/openclash.log"
LOGTIME=$(date "+%Y-%m-%d %H:%M:%S")
		
LOG_OUT()
{
	if [ -n "${1}" ]; then
		echo -e "${1}" > $START_LOG
		echo -e "${LOGTIME} ${1}" >> $LOG_FILE
	fi
}

LOG_CLEAN()
{
	echo "" > $START_LOG
}

LOG_OUT "Uninstalling The Old Version, Please Do not Refresh The Page or Do Other Operations..."
uci set openclash.config.enable=0
uci commit openclash
opkg remove --force-depends --force-remove luci-app-openclash
LOG_OUT "Installing The New Version, Please Do Not Refresh The Page or Do Other Operations..."
opkg install /tmp/openclash.ipk
if [ "$?" -eq "0" ]; then
   rm -rf /tmp/openclash.ipk >"/dev/null" 2>&1
   LOG_OUT "OpenClash Update Successful, About To Restart!"
   sleep 3
   uci set openclash.config.enable=1
   uci commit openclash
   /etc/init.d/openclash restart 2>"/dev/null"
else
   LOG_OUT "OpenClash Update Failed, The File is Saved in /tmp/openclash.ipk, Please Try to Update Manually!"
   sleep 3
   LOG_CLEAN
fi
EOF
   chmod 4755 /tmp/openclash_update.sh
   nohup /tmp/openclash_update.sh &
   wait
   rm -rf /tmp/openclash_update.sh
   else
      LOG_OUT "【OpenClash - v$LAST_VER】Download Failed, Please Check The Network or Try Again Later!"
      rm -rf /tmp/openclash.ipk >"/dev/null" 2>&1
      sleep 3
      LOG_CLEAN
      if [ "$(uci get openclash.config.config_reload 2>"/dev/null")" -eq 0 ]; then
         uci set openclash.config.config_reload=1
         uci commit openclash
      	 /etc/init.d/openclash restart 2>"/dev/null"
      fi
   fi
else
   if [ ! -f "$LAST_OPVER" ]; then
      LOG_OUT "Failed to Get Version Information, Please Try Again Later..."
      sleep 3
      LOG_CLEAN
   else
      LOG_OUT "OpenClash Has not Been Updated, Stop Continuing!"
      sleep 3
      LOG_CLEAN
   fi
   if [ "$(uci get openclash.config.config_reload 2>"/dev/null")" -eq 0 ]; then
      uci set openclash.config.config_reload=1
      uci commit openclash
      /etc/init.d/openclash restart 2>"/dev/null"
   fi
fi
DEL_LOCK "878" "_update"