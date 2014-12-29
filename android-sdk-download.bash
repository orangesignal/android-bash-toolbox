#!/bin/bash -e

uname_val=$(uname)
platform='linux'
ext='tgz'
if test "$uname_val" = 'Darwin'; then
	platform='macosx'
	ext='zip'
fi

#ANDROID_HOME="${PWD}/android-sdk-${platform}"
#ANDROID_HOME="${HOME}/android-sdk-${platform}"
#ANDROID_HOME="${JENKINS_HOME}/tools/android-sdk-${platform}"
#ANDROID_HOME="/Applications/android-sdk-${platform}"

# remove slash from the end of a ANDROID_HOME
export ANDROID_HOME="${ANDROID_HOME%/}"

if [[ ! -f "$ANDROID_HOME/tools/android" ]]; then
	echo 'Check remote sdk version...'
	html=$(curl --ipv4 --location --silent http://developer.android.com/sdk/index.html)
	sdk_ver=$(echo "$html" | grep 'android-sdk_r' | grep "${platform}.${ext}" | sed -e "s/.*android\-sdk_r\([0-9.]\{1,\}\)\-${platform}\.${ext}.*/\1/g")
	if test "$sdk_ver" = ''; then
		echo 'ERROR - Unknown remote sdk version'
		if test "$BASH_SOURCE" != "$0"; then
			return 1
		else
			exit 1
		fi
	fi

	# Download
	url="http://dl.google.com/android/android-sdk_r${sdk_ver}-${platform}.${ext}"
	archive_path="${PWD}/${url##*/}"
	if [[ ! -f "$archive_path" ]]; then
		echo "Downloading Android SDK Tools from $url"
		status=$(curl --ipv4 --location --output "$archive_path" --silent --write-out '%{http_code}' $url)
		if test "$status" != '200'; then
			echo "ERROR - Download failed: $status"
			if test "$BASH_SOURCE" != "$0"; then
				return 1
			else
				exit 1
			fi
		fi
	fi

	# Extract
	if test "$ANDROID_HOME" = ''; then
		export ANDROID_HOME="${PWD}/android-sdk-${platform}"
	fi
	echo "Extracting Android SDK Tools to $ANDROID_HOME"
	parent_dir=$(dirname "$ANDROID_HOME")
	if test "$ext" = 'zip'; then
#		unzip -t "$archive_path"
		set +e
		unzip -o "$archive_path"
		set -e
	elif test "$ext" = 'tgz'; then
		gzip -dc "$archive_path" | tar xvf -
	else
		echo "ERROR - Unknown archive format: $ext"
		if test "$BASH_SOURCE" != "$0"; then
			return 1
		else
			exit 1
		fi
	fi
	if test "$ANDROID_HOME" != "${PWD}/android-sdk-${platform}"; then
		if [[ -e "$ANDROID_HOME" ]]; then
			rm -rf "$ANDROID_HOME"
		fi
		mv "${PWD}/android-sdk-${platform}" "$ANDROID_HOME"
	fi
fi