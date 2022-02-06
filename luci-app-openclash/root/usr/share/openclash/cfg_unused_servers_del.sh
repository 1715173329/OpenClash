#!/bin/sh
. /usr/share/openclash/openclash_functions.sh

cfg_unused_servers_del()
{
	local section="$1"
	local enabled
	config_get_bool enabled "$section" "enabled" "1"

	if [ "$enabled" = "1" ]; then
		return
	else
		#删除未选中节点
		uci -q delete "$_CFG_NAME.$section"
	fi
}

	config_load "$_CFG_NAME"
	config_foreach cfg_unused_servers_del "servers"
	uci commit "$_CFG_NAME"
