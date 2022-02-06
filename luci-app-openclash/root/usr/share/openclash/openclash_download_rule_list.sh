#!/bin/sh
. /usr/share/openclash/openclash_functions.sh

urlencode() {
	local data
	if [ "$#" -eq 1 ]; then
		data="$(curl -s -o /dev/null -w %{url_effective} --get --data-urlencode "$1" "")"
		[ ! -z "$data" ] || echo "$(echo ${data##/?} |sed -e 's/\//%2f/g' -e 's/:/%3a/g' -e 's/?/%3f/g' -e 's/(/%28/g' -e 's/)/%29/g' -e 's/\^/%5e/g' -e 's/=/%3d/g' -e 's/|/%7c/g' -e 's/+/%20/g')"
	fi
}

config_load "$_CFG_NAME"
config_get_oc RELEASE_BRANCH "release_branch" "master"

RULE_FILE_NAME="$1"
if [ "$1" = "netflix_domains" ]; then
	DOWNLOAD_PATH="$_REPO_URL_RAW_PREFIX/$RELEASE_BRANCH/luci-app-openclash/root/usr/share/openclash/res/Netflix_Domains.list"
	DOWNLOAD_PATH2="https://cdn.jsdelivr.net/gh/$_REPO_NAME@$RELEASE_BRANCH/luci-app-openclash/root/usr/share/openclash/res/Netflix_Domains.list"
	RULE_FILE_PATH="$_RES_PATH/res/Netflix_Domains.list"
	RULE_FILE_NAME="Netflix_Domains"
	RULE_TYPE="netflix"
elif [ "$1" = "disney_domains" ]; then
	DOWNLOAD_PATH="$_REPO_URL_RAW_PREFIX/$RELEASE_BRANCH/luci-app-openclash/root/usr/share/openclash/res/Disney_Plus_Domains.list"
	DOWNLOAD_PATH2="https://cdn.jsdelivr.net/gh/$_REPO_NAME@$RELEASE_BRANCH/luci-app-openclash/root/usr/share/openclash/res/Disney_Plus_Domains.list"
	RULE_FILE_PATH="$_RES_PATH/res/Disney_Plus_Domains.list"
	RULE_FILE_NAME="Disney_Plus_Domains"
	RULE_TYPE="disney"
elif ! grep -qs "$RULE_FILE_NAME" "$_RES_PATH/res/rule_providers.list"; then
	DOWNLOAD_PATH="$(grep -sF "$RULE_FILE_NAME" "$_RES_PATH/res/game_rules.list" | awk -F ',' '{print $2}')"
	RULE_FILE_PATH="$_CFG_PATH/game_rules/$RULE_FILE_NAME"
	RULE_TYPE="game"
else
	DOWNLOAD_PATH="$(echo "$RULE_FILE_NAME" | awk -F ',' '{print $1$2}')"
	RULE_FILE_NAME="$(grep -sF "$RULE_FILE_NAME" "$_RES_PATH/res/rule_providers.list" | awk -F ',' '{print $NF}')"
	RULE_FILE_PATH="$_CFG_PATH/rule_provider/$RULE_FILE_NAME"
	RULE_TYPE="provider"
fi

[ -n "$DOWNLOAD_PATH" ] || {
	LOG_OUT "Rule file [$RULE_FILE_NAME] has no valid download url!"
	LOG_CLEAN

	exit 0
}

TMP_RULE_PATH="/tmp/$RULE_FILE_NAME"
TMP_RULE_PATH_TMP="/tmp/$RULE_FILE_NAME.tmp"
{ [ "$RULE_TYPE" != "netflix" ] && [ "$RULE_TYPE" != "disney" ]; } && DOWNLOAD_PATH=$(urlencode "$DOWNLOAD_PATH")

if [ "$RULE_TYPE" = "netflix" ] || [ "$RULE_TYPE" = "disney" ]; then
	for i in "$DOWNLOAD_PATH" "$DOWNLOAD_PATH2"; do
		CURL_GET_SMALL_FILE "$DOWNLOAD_PATH" -o "$TMP_RULE_PATH" && break
	done
elif [ "$RULE_TYPE" = "game" ]; then
	IS_CLASH_RUNNING && CURL_GET_SMALL_FILE "https://raw.githubusercontent.com/FQrabbit/SSTap-Rule/master/rules/$DOWNLOAD_PATH" -o "$TMP_RULE_PATH" || \
		CURL_GET_SMALL_FILE "https://cdn.jsdelivr.net/gh/FQrabbit/SSTap-Rule@master/rules/$DOWNLOAD_PATH" -o "$TMP_RULE_PATH"
elif [ "$RULE_TYPE" = "provider" ]; then
	IS_CLASH_RUNNING && CURL_GET_SMALL_FILE "https://raw.githubusercontent.com/$DOWNLOAD_PATH" -o "$TMP_RULE_PATH" || \
		CURL_GET_SMALL_FILE "https://cdn.jsdelivr.net/gh/$(echo "$DOWNLOAD_PATH" | awk -F '/master' '{print $1}')@master$(echo "$DOWNLOAD_PATH" |awk -F 'master' '{print $2}')" -o "$TMP_RULE_PATH"
fi

if [ "$?" -eq "0" ] && [ -s "$TMP_RULE_PATH" ] && ! grep -qs "404: Not Found" "$TMP_RULE_PATH" && ! grep -qs "Package size exceeded the configured limit" "$TMP_RULE_PATH"; then
	[ "$RULE_TYPE" != "game" ] || {
		cat "$TMP_RULE_PATH" 2>"/dev/null" | sed -e '/^#/d' -e '/^ *$/d' | awk '{print "  - "$0}' > "$TMP_RULE_PATH_TMP"
		sed -i '1i\payload:' "$TMP_RULE_PATH_TMP" 2>"/dev/null"
		mv -f "$TMP_RULE_PATH_TMP" "$TMP_RULE_PATH" 2>"/dev/null"
	}

	if ! cmp -s "$TMP_RULE_PATH" "$RULE_FILE_PATH"; then
		mv -f "$TMP_RULE_PATH" "$RULE_FILE_PATH" 2>"/dev/null"

		LOG_OUT "Rule File [$RULE_FILE_NAME] is updated successfully!"
		LOG_CLEAN

		exit 1
	else
		rm -f "$TMP_RULE_PATH"

		LOG_OUT "Rule File [$RULE_FILE_NAME] is up-to-date!"
		LOG_CLEAN

		exit 2
	fi
else
	rm -f "$TMP_RULE_PATH"

	LOG_OUT "Rule File [$RULE_FILE_NAME] is failed to download!"
	LOG_CLEAN

	exit 0
fi
