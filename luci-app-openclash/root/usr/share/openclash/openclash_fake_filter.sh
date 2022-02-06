#!/bin/sh
. /usr/share/openclash/openclash_functions.sh

CUSTOM_FILE="$_CFG_PATH/custom/${CFG_NAME}_custom_fake_filter.list"
FAKE_FILTER_FILE="/tmp/${CFG_NAME}_fake_filter.list"
SER_FAKE_FILTER_FILE="/tmp/${CFG_NAME}_servers_fake_filter.conf"

LOG_OUT "Setting Fake IP Filter..."

rm -f "$FAKE_FILTER_FILE" "$SER_FAKE_FILTER_FILE"

if [ -s "$CUSTOM_FILE" ]; then
	cat "$CUSTOM_FILE" | while read -r line; do
		if ! echo "$line" |grep -q '^ \{0,\}#'; then
			echo "  - '$line'" >> "$FAKE_FILTER_FILE"
		else
			continue
		fi
	done 2>"/dev/null"

	if [ -s "$FAKE_FILTER_FILE" ]; then
		sed -i '1i\fake-ip-filter:' "$FAKE_FILTER_FILE" 2>"/dev/null"
	else
		rm -f "$FAKE_FILTER_FILE"
	fi
fi

cfg_server_address()
{
	local section="$1"
	local server
	config_get server "$section" "server"
   
	IFIP="$(echo "$server" |grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$")"
	if [ -z "$IFIP" ] && [ -n "$server" ] && ! grep -qs "/$server/" "$SER_FAKE_FILTER_FILE"; then
		echo "server=/$server/$custom_domain_dns_server" >> "$SER_FAKE_FILTER_FILE"
	else
		return
	fi
}

# Fake 下正确检测节点延迟及获取真实地址
config_load "openclash"
config_get_oc custom_domain_dns_server "" "114.114.114.114"
config_foreach cfg_server_address "servers"