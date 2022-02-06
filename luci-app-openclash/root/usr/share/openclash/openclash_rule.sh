#!/bin/sh
. /usr/share/openclash/openclash_functions.sh
. /usr/share/openclash/ruby.sh

yml_other_rules_dl() {
	local section="$1"
	local enabled config
	config_get_bool "enabled" "$section" "enabled" "1"
	config_get "config" "$section" "config"
   
	if [ "$enabled" = "0" ] || [ "$config" != "$2" ]; then
		return
	fi
   
	if [ -n "$rule_name" ]; then
		LOG_OUT "Warning: multiple Other-Rules-Configurations are enabled, ignoring..."
		return
	fi
   
	config_get "rule_name" "$section" "rule_name"
   
	LOG_OUT "Start Downloading Third Party Rules in Use..."
	local TMP_RULES="/tmp/rules.yaml"
	case "rule_name" in
	"lhie1")
		IS_CLASH_RUNNING && CURL_GET_FILE "https://raw.githubusercontent.com/dler-io/Rules/master/Clash/Rule.yaml" -o "$TMP_RULES" || \
			CURL_GET_FILE https://cdn.jsdelivr.net/gh/dler-io/Rules@master/Clash/Rule.yaml -o "$TMP_RULES"
		sed -i '1i rules:' $TMP_RULES
		;;
	"ConnersHua")
		IS_CLASH_RUNNING && https://raw.githubusercontent.com/DivineEngine/Profiles/master/Clash/Outbound.yaml -o "$TMP_RULES" || \
			CURL_GET_FILE https://cdn.jsdelivr.net/gh/DivineEngine/Profiles@master/Clash/Outbound.yaml -o "$TMP_RULES"
		sed -i -e "s/# - RULE-SET,ChinaIP,DIRECT/- RULE-SET,ChinaIP,DIRECT/g" -e "s/- GEOIP,/#- GEOIP,/g" "$TMP_RULES"
		;;
	"ConnersHua_return")
		IS_CLASH_RUNNING && CURL_GET_FILE https://raw.githubusercontent.com/DivineEngine/Profiles/master/Clash/Inbound.yaml -o "$TMP_RULES" || \
			CURL_GET_FILE https://cdn.jsdelivr.net/gh/DivineEngine/Profiles@master/Clash/Inbound.yaml -o "$TMP_RULES"
		;;
	esac

	if [ "$?" -eq "0" ] && [ -s "$TMP_RULES" ]; then
		LOG_OUT "Succeeded in downloading rule file, start preprocessing..."

		ruby -ryaml -E UTF-8 -e "
		begin
		YAML.load_file('$TMP_RULES');
		rescue Exception => e
		puts '${LOGTIME} Error: Unable to parse new rule file, [${rule_name}: ' + e.message + ']'
		system 'rm -f $TMP_RULES 2>/dev/null'
		end
		" 2>"/dev/null" >> "$LOG_FILE"

		if [ $? -ne 0 ]; then
			RULE_ERROR_LOG="Error: Ruby works abnormally. Please check dependencies of ruby library!"
		elif [ ! -f "$TMP_RULES" ]; then
			RULE_ERROR_LOG="Error: [$rule_name] Rule file format validation is failed. Please try again."
		elif ! "$(ruby_read "$TMP_RULES" ".key?('rules')")"; then
			RULE_ERROR_LOG="Error: New 3rd-party rules [$rule_name] has no \"rules\" field, skipping..."
		# 校验是否含有新策略组
		elif ! ruby -ryaml -E UTF-8 -e "
				Value = YAML.load_file('$_RES_PATH/res/${rule_name}.yaml');
				Value_1 = YAML.load_file('$TMP_RULES');
				OLD_GROUP = Value['rules'].collect{|x| x.split(',')[2] or x.split(',')[1]}.uniq;
				NEW_GROUP = Value_1['rules'].collect{|x| x.split(',')[2] or x.split(',')[1]}.uniq;
				puts (OLD_GROUP | NEW_GROUP).eql?(OLD_GROUP)
				" >"/dev/null" 2>&1 ; then
			RULE_ERROR_LOG="Error: New 3rd-party rules [$rule_name] has incompatible \"Proxy-Group\", skipping... Please wait for new OpenClash version."
		fi
		[ -z "$RULE_ERROR_LOG" ] || {
			rm -f "$TMP_RULES"

			LOG_OUT "$RULE_ERROR_LOG"
			sleep 3
			LOG_CLEAN

			DEL_LOCK "877" "_rule"
			exit 0
		}

		# 取出规则部分
		ruby_read "$TMP_RULES" ".select {|x| 'rule-providers' == x or 'script' == x or 'rules' == x }.to_yaml" > "$OTHER_RULE_FILE"
		# 合并
		cat "$OTHER_RULE_FILE" > "$TMP_RULES"
		rm -f "$OTHER_RULE_FILE"

		if ! cmp -s "$_RES_PATH/res/$rule_name.yaml" "$TMP_RULES"; then
			LOG_OUT "Replacing the old one..."
			mv -f "$TMP_RULES" "$_RES_PATH/res/$rule_name.yaml" 2>"/dev/null"
			LOG_OUT "3rd-party rules [$rule_name] is updated successfully!"
			NEED_RESTART=1
		else
			LOG_OUT "3rd-party rules [$rule_name] is up-to-date."
		fi
   else
		LOG_OUT "Failed to downlaod 3rd-party rules [$rule_name]. Please check your network and try again later..."
   fi

	sleep 3
	rm -f "$TMP_RULES"
}

LOGTIME="$(date "+%Y-%m-%d %H:%M:%S")"

config_load "openclash"
config_get_oc_bool RUlE_SOURCE "rule_source"
   
SET_LOCK "877" "_rule"

if [ "$RUlE_SOURCE" -eq "0" ]; then
	LOG_OUT "3rd-party rules are not enabled, stopped."
	sleep 3
else
	OTHER_RULE_FILE="/tmp/other_rule.yaml"
	config_get_oc CONFIG_FILE "config_path"
	CONFIG_NAME="${CONFIG_FILE##*/}"
	NEED_RESTART=0

	if [ -z "$CONFIG_FILE" ]; then
		CONFIG_FILE="$(ls -t "$_CFG_PATH/config/"*.y*ml | head -n1)"
		CONFIG_NAME="${CONFIG_FILE##*/}"
	fi

	if [ -z "$CONFIG_NAME" ]; then
	   CONFIG_FILE="$_CFG_PATH/config/config.yaml"
	   CONFIG_NAME="config.yaml"
	fi
	
	config_foreach yml_other_rules_dl "other_rules" "$CONFIG_NAME"
	if [ -z "$rule_name" ]; then
		LOG_OUT "3rd-party rules setting is not found, stopped."
		sleep 3
	fi

	if [ "$NEED_RESTART" -eq 1 ] && ! IS_INIT_RUNNING; then
		/etc/init.d/openclash restart >"/dev/null" 2>&1 &
	fi
fi

LOG_CLEAN

DEL_LOCK "877" "_rule"
