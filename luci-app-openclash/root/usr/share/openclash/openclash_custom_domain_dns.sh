#!/bin/sh
. /usr/share/openclash/openclash_functions.sh

SET_LOCK "883" "_cus_domain"

rm -rf "/tmp/dnsmasq.d/dnsmasq_${_CFG_NAME}_custom_domain.conf"

config_load "$_CFG_NAME"
config_get_oc_bool dns_advanced_setting

if [ "$dns_advanced_setting" -eq "1" ]; then
	LOG_OUT "Setting Secondary DNS Server List..."

	config_get_oc custom_domain_dns_server "" "114.114.114.114"
	if [ -s "$_CFG_PATH/custom/${_CFG_NAME}_custom_domain_dns.list" ]; then
		mkdir -p "/tmp/dnsmasq.d"
		awk -v tag="$custom_domain_dns_server" '!/^$/&&!/^#/{printf("server=/%s/"'tag'"\n",$0)}' "$_CFG_PATH/custom/${_CFG_NAME}_custom_domain_dns.list" >> "/tmp/dnsmasq.d/dnsmasq_${_CFG_NAME}_custom_domain.conf" 2>"/dev/null"
	fi
fi

DEL_LOCK "883" "_cus_domain"
