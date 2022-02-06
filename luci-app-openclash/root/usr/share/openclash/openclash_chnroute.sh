#!/bin/sh
. /usr/share/openclash/openclash_functions.sh

config_load "$_CFG_NAME"
config_get_oc china_ip_route
config_get_oc china_ip6_route
config_get_oc chnr_download_url "chnr_custom_url" "https://ispip.clang.cn/all_cn.txt"
config_get_oc chnr6_download_url "chnr6_custom_url" "https://ispip.clang.cn/all_cn_ipv6.txt"
config_get_oc disable_udp_quic
config_get_oc small_flash_memory

SET_LOCK "879" "_chn"

[ "$small_flash_memory" -ne "1" ] || DIR_PREFIX="/tmp"
chnroute_path="${DIR_PREFIX}${_CFG_PATH}"
mkdir -p "$chnroute_path"

# IPv4
LOG_OUT "Downloading chroute data..."

chnr_path="$chnroute_path/china_ip_route.ipset"
tmp_chnr_path="/tmp/china_ip_route"

if CURL_GET_FILE "$chnr_download_url" -o "$tmp_chnr_path.txt" && [ -s "$tmp_chnr_path.txt" ]; then
	LOG_OUT "Succeeded in downloading chnroute data."

	# 预处理
	echo "create china_ip_route hash:net family inet hashsize 1024 maxelem 1000000" > "$tmp_chnr_path.list"
	awk '!/^$/&&!/^#/{printf("add china_ip_route %s'" "'\n",$0)}' "$tmp_chnr_path.txt" >> "$tmp_chnr_path.list"

	if ! cmp -s "$tmp_chnr_path.list" "$chnr_path"; then
		LOG_OUT "chnroute data is updated, replacing the old one..."
		mv -f "$tmp_chnr_path" "$chnr_path" >"/dev/null" 2>&1

		if [ "$china_ip_route" -eq 1 ] || [ "$disable_udp_quic" -eq 1 ]; then
			NEED_RESTART=1
		fi

		LOG_OUT "chnroute data is successfully updated!"
	else
		LOG_OUT "chnroute data is up-to-date."
	fi

	rm -f "$tmp_chnr_path.txt" "$tmp_chnr_path.list"
else
	LOG_OUT "Failed to fetch chnroute data, please try again later."
fi
sleep 3

# IPv6
LOG_OUT "Downloading chnroute6 data..."

chnr6_path="$chnroute_path/china_ip6_route.ipset"
tmp_chnr6_path="/tmp/china_ip6_route"

if CURL_GET_FILE "$chnr6_download_url" -o "$tmp_chnr6_path.txt" && [ -s "$tmp_chnr6_path.txt" ]; then
	LOG_OUT "Succeeded in downloading chnroute6 data."

	# 预处理
	echo "create china_ip6_route hash:net family inet6 hashsize 1024 maxelem 1000000" > "$tmp_chnr6_path.list"
	awk '!/^$/&&!/^#/{printf("add china_ip6_route %s'" "'\n",$0)}' "$tmp_chnr6_path.txt" >> "$tmp_chnr6_path.list"

	if ! cmp -s "$tmp_chnr6_path.list" "$chnr6_path"; then
		LOG_OUT "chnroute6 data is updated, replacing the old one..."
		mv -f "$tmp_chnr6_path.list" "$chnr6_path" >"/dev/null" 2>&1

		if [ "$china_ip6_route" -eq 1 ] || [ "$disable_udp_quic" -eq 1 ]; then
			NEED_RESTART=1
		fi

		LOG_OUT "chnroute6 data is successfully updated!"
	else
		LOG_OUT "chnroute6 data is up-to-date."
	fi

	rm -f "$tmp_chnr6_path.txt" "$tmp_chnr6_path.list"
else
	LOG_OUT "Failed to fetch chnroute6 data, please try again later."
fi

if [ "$NEED_RESTART" = "1" ] && ! IS_INIT_RUNNING; then
	/etc/init.d/$_GLOBAL_NAME restart >"/dev/null" 2>&1 &
 fi

sleep 3

LOG_CLEAN

DEL_LOCK "879" "_chn"
