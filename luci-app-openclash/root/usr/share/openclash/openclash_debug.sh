#!/bin/bash
. /etc/openwrt_release
. /usr/share/openclash/openclash_functions.sh
. /usr/share/openclash/ruby.sh

uci -q commit "$_CFG_NAME"

get_opkg_info() {
	opkg status "$1" | grep "$2" | awk -F ': ' '{print $2}'
}

get_opkg_insstat() {
	if [ -n "$(get_opkg_info "$1" "Status")" ]; then
		echo "${1}${2}: 已安装"
	else
		echo "${1}${2}: 未安装"
	fi
}

is_enabled() {
	local enabled
	config_get_bool enabled "config" "$1" "{$2:-0}"
	if [ "$enabled" -eq "1" ]; then
		echo "启用"
	else
		echo "禁用"
	fi
}

DEBUG_LOG="/tmp/${_GLOBAL_NAME}_debug.log"
LOGTIME="$(date "+%Y-%m-%d %H:%M:%S")"

SET_LOCK "885" "_debug"

config_load "$_CFG_NAME"
config_get_oc en_mode
config_get_oc core_type "core_version" "0"
config_get_oc proxy_mode
config_get_oc raw_config_file "config_path"
config_get_bool enable_custom_clash_rules

core_dev_version=$($_CFG_PATH/core/clash -v 2>"/dev/null" | awk -F ' ' '{print $2}')
core_tun_version=$($_CFG_PATH/core/clash_tun -v 2>"/dev/null" | awk -F ' ' '{print $2}')
openclash_version=$(sed -n 1p "$_RES_PATH/res/${_GLOBAL_NAME}_version")

config_file="${raw_config_file/\/config\//\/}"
if [ -z "$raw_config_file" ] || [ ! -f "$raw_config_file" ]; then
	config_name="$(ls -lt $_CFG_PATH/config/ | grep -E '.yaml|.yml' | head -n1 | awk '{print $9}')"
	[ -z "$config_name" ] || {
		raw_config_file="$_CFG_PATH/config/$config_name"
		config_file="$_CFG_PATH/$config_name"
	}
fi

echo "OpenClash 调试日志" > "$DEBUG_LOG"
cat >> "$DEBUG_LOG" <<-EOF

生成时间: $LOGTIME
插件版本: $openclash_version
隐私提示: 上传此日志前请注意检查、屏蔽公网 IP、节点、密码等相关敏感信息

\`\`\`
EOF

cat >> "$DEBUG_LOG" <<-EOF

#===================== 系统信息 =====================#

主机型号: $(cat /tmp/sysinfo/model 2>"/dev/null")
固件版本: $DISTRIB_DESCRIPTION
LuCI 版本: $(get_opkg_info "luci" "Version")
内核版本: $(uname -r)
处理器架构: $DISTRIB_ARCH

# 此项有值时，如不使用 IPv6，建议到 网络-接口-lan 的设置中禁用 IPV6 的 DHCP
IPV6-DHCP: $(uci -q get dhcp.lan.dhcpv6)

# 此项结果应仅有配置文件的 DNS 监听地址
Dnsmasq 转发设置: $(uci -q get dhcp.@dnsmasq[0].server)
EOF

cat >> "$DEBUG_LOG" <<-EOF

#===================== 依赖检查 =====================#

$(for i in "dnsmasq-full" "coreutils" "coreutils-nohup" "bash" "curl" "ca-certificates" "ipset" "ip-full" \
		"iptables-mod-tproxy" "kmod-ipt-tproxy" "iptables-mod-extra" "kmod-ipt-extra" "libcap" "libcap-bin" \
		"ruby" "ruby-yaml" "ruby-psych" "ruby-pstore" "ruby-dbm"; do
	get_opkg_insstat "$i" ; \
done)
$(get_opkg_insstat "kmod-tun" "(TUN 模式)")
$(get_opkg_insstat "luci-compat" "(LuCI 19.07+)")
EOF

# core
cat >> "$DEBUG_LOG" <<-EOF

#===================== 内核检查 =====================#

EOF

if IS_CLASH_RUNNING; then
	cat >> "$DEBUG_LOG" <<-EOF
	运行状态: 运行中
	进程 pid: $(pidof clash)
	运行权限: $(getpcaps $(pidof clash))
	运行用户: $($_PS | grep "$_CFG_PATH/clash" | grep -v grep |awk '{print $2}')
	EOF
else
	cat >> "$DEBUG_LOG" <<-EOF
	运行状态: 未运行
	EOF
fi

if [ "$core_type" = "0" ]; then
   core_type="未选择架构"
fi
cat >> "$DEBUG_LOG" <<-EOF
已选择的架构: $core_type

# 下方无法显示内核版本号时请确认您的内核版本是否正确或者有无权限
EOF

cat >> "$DEBUG_LOG" <<-EOF
Tun 内核版本: $core_tun_version
EOF
if [ ! -f "$_CFG_PATH/core/clash_tun" ]; then
	cat >> "$DEBUG_LOG" <<-EOF
	Tun 内核文件: 不存在
	EOF
else
	cat >> "$DEBUG_LOG" <<-EOF
	Tun 内核文件: 存在
	EOF
fi
if [ ! -x "$_CFG_PATH/core/clash_tun" ]; then
	cat >> "$DEBUG_LOG" <<-EOF
	Tun 内核运行权限: 无
	EOF
else
	cat >> "$DEBUG_LOG" <<-EOF
	Tun 内核运行权限: 正常
	EOF
fi

cat >> "$DEBUG_LOG" <<-EOF

Dev 内核版本: $core_dev_version
EOF
if [ ! -f "$_CFG_PATH/core/clash" ]; then
	cat >> "$DEBUG_LOG" <<-EOF
	Dev 内核文件: 不存在
	EOF
else
	cat >> "$DEBUG_LOG" <<-EOF
	Dev 内核文件: 存在
	EOF
fi
if [ ! -x "$_CFG_PATH/core/clash" ]; then
	cat >> "$DEBUG_LOG" <<-EOF
	Dev 内核运行权限: 否
	EOF
else
	cat >> "$DEBUG_LOG" <<-EOF
	Dev 内核运行权限: 正常
	EOF
fi

cat >> "$DEBUG_LOG" <<-EOF

#===================== 插件设置 =====================#

当前配置文件: $raw_config_file
启动配置文件: $config_file
运行模式: $en_mode
默认代理模式: $proxy_mode
UDP 流量转发 (tproxy): $(is_enabled "enable_udp_proxy")
DNS 劫持: $(is_enabled "enable_redirect_dns")
自定义 DNS: $(is_enabled "enable_custom_dns")
IPv6 代理: $(is_enabled "ipv6_enable")
IPv6-DNS 解析: $(is_enabled "ipv6_dns")
禁用 Dnsmasq 缓存: $(is_enabled "disable_masq_cache")
自定义规则: $(is_enabled "enable_custom_clash_rules")
仅允许内网: $(is_enabled "intranet_allowed")
仅代理命中规则流量: $(is_enabled "enable_rule_proxy")
仅允许常用端口流量: $(is_enabled "common_ports")
绕过中国大陆 IP: $(is_enabled "china_ip_route")
DNS 远程解析: $(is_enabled "dns_remote")

# 启动异常时建议关闭此项后重试
混合节点: $(is_enabled "mix_proxies")
保留配置: $(is_enabled "servers_update")
EOF

cat >> "$DEBUG_LOG" <<-EOF

# 启动异常时建议关闭此项后重试
第三方规则: $(is_enabled "rule_source")
EOF


if [ "$enable_custom_clash_rules" -eq "1" ]; then
cat >> "$DEBUG_LOG" <<-EOF

#===================== 自定义规则 一 =====================#
EOF
cat "$_CFG_PATH/custom/${_CFG_NAME}_custom_rules.list" >> "$DEBUG_LOG" 2>&1

cat >> "$DEBUG_LOG" <<-EOF

#===================== 自定义规则 二 =====================#
EOF
cat "$_CFG_PATH/custom/${_CFG_NAME}_custom_rules_2.list" >> "$DEBUG_LOG" 2>&1
fi

cat >> "$DEBUG_LOG" <<-EOF

#===================== 配置文件 =====================#

EOF
if [ -f "$config_file" ]; then
   ruby_read "$config_file" ".select {|x| 'proxies' != x and 'proxy-providers' != x }.to_yaml" 2>"/dev/null" >> "$DEBUG_LOG"
else
   ruby_read "$raw_config_file" ".select {|x| 'proxies' != x and 'proxy-providers' != x }.to_yaml" 2>"/dev/null" >> "$DEBUG_LOG"
fi

sed -i '/^ \{0,\}secret:/d' "$DEBUG_LOG" 2>"/dev/null"

#firewall
cat >> "$DEBUG_LOG" <<-EOF

#===================== 防火墙设置 =====================#

# IPv4 NAT chain

EOF
iptables-save -t nat >> "$DEBUG_LOG" 2>"/dev/null"

cat >> "$DEBUG_LOG" <<-EOF

# IPv4 Mangle chain

EOF
iptables-save -t mangle >> "$DEBUG_LOG" 2>"/dev/null"

cat >> "$DEBUG_LOG" <<-EOF

# IPv6 NAT chain

EOF
ip6tables-save -t nat >> "$DEBUG_LOG" 2>"/dev/null"

cat >> "$DEBUG_LOG" <<-EOF

# IPv6 Mangle chain

EOF
ip6tables-save -t mangle >> "$DEBUG_LOG" 2>"/dev/null"

cat >> "$DEBUG_LOG" <<-EOF

#===================== IPSET 状态 =====================#

EOF
ipset list | grep "Name:" >> "$DEBUG_LOG"

cat >> "$DEBUG_LOG" <<-EOF

#===================== 路由表状态 =====================#

EOF
echo "# route -n" >> "$DEBUG_LOG"
route -n >> "$DEBUG_LOG" 2>"/dev/null"
echo "# ip route list" >> "$DEBUG_LOG"
ip route list >> "$DEBUG_LOG" 2>"/dev/null"
echo "# ip rule show" >> "$DEBUG_LOG"
ip rule show >> "$DEBUG_LOG" 2>"/dev/null"

if [ "$en_mode" != "fake-ip" ] && [ "$en_mode" != "redir-host" ]; then
cat >> "$DEBUG_LOG" <<-EOF

#===================== Tun 设备状态 =====================#

EOF
ip tuntap list >> "$DEBUG_LOG" 2>"/dev/null"
fi

cat >> "$DEBUG_LOG" <<-EOF

#===================== 端口占用状态 =====================#

EOF
netstat -nlp | grep "clash" >> "$DEBUG_LOG"

cat >> "$DEBUG_LOG" <<-EOF

#===================== 测试本机 DNS 查询 =====================#

EOF
nslookup "www.baidu.com" >> "$DEBUG_LOG" 2>&1

if [ -s "/tmp/resolv.conf.auto" ]; then
cat >> "$DEBUG_LOG" <<-EOF

#===================== resolv.conf.auto =====================#

EOF
cat "/tmp/resolv.conf.auto" >> "$DEBUG_LOG" 2>&1
fi

if [ -s "/tmp/resolv.conf.d/resolv.conf.auto" ]; then
cat >> "$DEBUG_LOG" <<-EOF

#===================== resolv.conf.d =====================#

EOF
cat "/tmp/resolv.conf.d/resolv.conf.auto" >> "$DEBUG_LOG" 2>&1
fi

cat >> "$DEBUG_LOG" <<-EOF

#===================== 测试本机网络连接 =====================#

EOF
curl -I -m 5 "www.baidu.com" >> "$DEBUG_LOG" 2>"/dev/null"

cat >> "$DEBUG_LOG" <<-EOF

#===================== 测试本机网络下载 =====================#

EOF
VERSION_URL="https://$_REPO_URL_RAW_PREFIX/master/version"
if pidof clash >/dev/null; then
   curl -IL -m 3 --retry 2 "$VERSION_URL" >> "$DEBUG_LOG" 2>"/dev/null"
else
   curl -IL -m 3 --retry 2 "$VERSION_URL" >> "$DEBUG_LOG" 2>"/dev/null"
fi

cat >> "$DEBUG_LOG" <<-EOF

#===================== 最近运行日志 =====================#

EOF
tail -n 50 "$LOG_FILE" >> "$DEBUG_LOG" 2>"/dev/null"

cat >> "$DEBUG_LOG" <<-EOF

#===================== 活动连接信息 =====================#

EOF
$_RES_PATH/openclash_debug_getcon.lua

cat >> "$DEBUG_LOG" <<-EOF

\`\`\`
EOF

DEL_LOCK "885" "_debug"
