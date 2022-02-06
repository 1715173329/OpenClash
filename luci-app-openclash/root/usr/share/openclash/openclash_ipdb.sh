#!/bin/sh
. /usr/share/openclash/openclash_functions.sh

config_load "$_CFG_NAME"
config_get_oc small_flash_memory
config_get_oc GEOIP_CUSTOM_URL "geo_custom_url"
   
SET_LOCK "880" "_ipdb"

[ "$small_flash_memory" -ne "1" ] || DIR_PREFIX="/tmp"
geoip_path="${DIR_PREFIX}${_CFG_DIR}/Country.mmdb"
tmp_geoip_path="/tmp/Country.mmdb"
mkdir -p "${geoip_path%/*}"

LOG_OUT "Downloading GeoIP database..."
if [ -z "$GEOIP_CUSTOM_URL" ]; then
	IS_CLASH_RUNNING && CURL_GET_FILE "https://raw.githubusercontent.com/alecthw/mmdb_china_ip_list/release/lite/Country.mmdb" -o "$tmp_geoip_path" || \
		CURL_GET_FILE "https://cdn.jsdelivr.net/gh/alecthw/mmdb_china_ip_list@release/lite/Country.mmdb" -o "$tmp_geoip_path"
else
	CURL_GET_FILE "$GEOIP_CUSTOM_URL" -o "$tmp_geoip_path"
fi

if [ "$?" -eq "0" ] && [ -s "$tmp_geoip_path" ]; then
	LOG_OUT "GeoIP database is downloaded successfully."
	if ! cmp -s "$tmp_geoip_path" "$geoip_path"; then
		LOG_OUT "Replacing the old one..."
		mv -f "$tmp_geoip_path" "$geoip_path" 2>"/dev/null"
		LOG_OUT "GeoIP database is updated successfully!"

		IS_INIT_RUNNING || /etc/init.d/openclash restart >"/dev/null" 2>&1 &
	else
		rm -f "$tmp_geoip_path"
		LOG_OUT "GeoIP database is up-to-date."
	fi
else
	rm -f "$tmp_geoip_path"
	LOG_OUT "Failed to download GeoIP database, please check your network and try again later."
fi

sleep 3
LOG_CLEAN

DEL_LOCK "880" "_ipdb"
