#!/bin/sh
. /usr/share/openclash/openclash_functions.sh

config_load "$_CFG_NAME"
config_get_oc en_mode

if IS_CLASH_RUNNING && [ -z "$(echo "$en_mode" | grep "redir-host")" ]; then
	rm -f "/tmp/dnsmasq.d/dnsmasq_${_CFG_NAME}.conf"

	$_RES_PATH/openclash_fake_filter.sh

	if [ -s "$_CFG_PATH/servers_fake_filter.conf" ]; then
		mkdir -p "/tmp/dnsmasq.d"
		cp -f "$_CFG_PATH/servers_fake_filter.conf" "/tmp/dnsmasq.d/dnsmasq_${_CFG_NAME}.conf" 2>"/dev/null"
		/etc/init.d/dnsmasq restart >"/dev/null" 2>&1
	fi

	LOG_CLEAN
fi
