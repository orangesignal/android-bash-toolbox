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

archive_paths=()

function installNdk() {
	local url="$1"
	local archive_path="${PWD}/${url##*/}"

	if test "$1"='clean'; then
		rm -f "$archive_path"
	fi

	if [[ ! -f "$archive_path" ]]; then
		echo "Downloading Android NDK from $url"
		local status=$(curl --ipv4 --location --output "$archive_path" --silent --write-out '%{http_code}' $url)
		if test "$status" != '200'; then
			echo "ERROR - Download failed: $status"
			return 1
		fi
	fi

	chmod 755 "$archive_path"
	echo 'all' | "$archive_path"
	archive_paths=("${archive_paths[@]}" "$archive_path")
}

function moveToNdkHomeIfNeed() {
	if test "$PWD" != "$parent_dir"; then
		echo "Moving $PWD/$ndk_dir to $parent_dir"
		mv "$PWD/$ndk_dir" "$parent_dir"
	fi
}

function removeArchiveFiles() {
	echo "Remove archive files..."
	local i
	for ((i = 0; i < ${#archive_paths[@]}; i++)) {
		local archive_path="${archive_paths[i]}"
		echo "rm -f $archive_path"
		rm -f "$archive_path"
	}
}

installNdk "http://dl.google.com/android/ndk/android-ndk-r${ndk_ver}-${platform}-x86.bin"
installNdk "http://dl.google.com/android/ndk/android-ndk-r${ndk_ver}-${platform}-x86_64.bin"
moveToNdkHomeIfNeed
removeArchiveFiles
