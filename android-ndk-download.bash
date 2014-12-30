#!/bin/bash -e

uname_val=$(uname)
platform='linux'
if test "$uname_val" = 'Darwin'; then
	platform='darwin'
fi

echo 'Check remote ndk version...'
html=$(curl --ipv4 --location --silent http://developer.android.com/tools/sdk/ndk/index.html)
ndk_ver=$(echo "$html" | grep 'android-ndk-r' | grep "${platform}-x86.bin" | sed -e "s/.*android\-ndk\-r\([0-9a-z.]\{1,\}\)\-${platform}\-x86\.bin.*/\1/g")
echo "$ndk_ver"
if test "$ndk_ver" = ''; then
	echo 'ERROR - Unknown remote ndk version'
	exit 1
fi

echo 'Validating ANDROID_NDK_HOME...'
ndk_dir="android-ndk-r${ndk_ver}"
if test "$ANDROID_NDK_HOME" = ''; then
	ANDROID_NDK_HOME="$PWD/$ndk_dir"
else
	echo "ANDROID_NDK_HOME=$ANDROID_NDK_HOME"
fi
parent_dir=$(dirname "$ANDROID_NDK_HOME")
if [[ -d "$parent_dir/$ndk_dir" ]]; then
	echo "Cancelled - $parent_dir/$ndk_dir already exists"
	exit 0
fi

function install_ndk() {
	local url="$1"
	local archive_path="${PWD}/${url##*/}"
	if [[ ! -f "$archive_path" ]]; then
		echo "Downloading Android NDK from $url"
		local status=$(curl --ipv4 --location --output "$archive_path" --write-out '%{http_code}' $url)
		if test "$status" != '200'; then
			echo "ERROR - Download failed: $status"
			return 1
		fi
	fi

	chmod 755 "$archive_path"
	echo 'all' | "$archive_path"
#	rm -f "$archive_path"
}

install_ndk "http://dl.google.com/android/ndk/android-ndk-r${ndk_ver}-${platform}-x86.bin"
install_ndk "http://dl.google.com/android/ndk/android-ndk-r${ndk_ver}-${platform}-x86_64.bin"
if test "$PWD" != "$parent_dir"; then
	mv "$PWD/$ndk_dir" "$parent_dir"
fi
