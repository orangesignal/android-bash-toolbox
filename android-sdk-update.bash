#!/bin/bash -e

shell_dir=$(dirname ${BASH_SOURCE:-$0})
source "$shell_dir/android-sdk-download.bash"

echo "Validating Android SDK - $ANDROID_HOME"
build_tools_dir="$ANDROID_HOME/build-tools"
filter=''

# latest build-tools
results=$("$ANDROID_HOME/tools/android" list sdk --extended --all --no-ui)
list=$(echo "$results" | grep 'id:' | cut -d \" -f2)
for item in ${list}; do
	case "$item" in
		build-tools-* )
			remote_ver=$(echo "$item" | sed 's/build-tools-//g')
			if [[ ! -d "$build_tools_dir/$remote_ver" ]]; then
				filter="${filter},${item}"
			fi
			break
			;;
	esac
done

# others
results=$("$ANDROID_HOME/tools/android" list sdk --extended --no-ui)
list=$(echo "$results" | grep 'id:' | cut -d \" -f2)
for item in ${list}; do
	case "$item" in
		platform-tools )
			filter="${filter},${item}"
			;;
		android-* )
			filter="${filter},${item}"
			;;
		addon-* )
			filter="${filter},${item}"
			;;
#		extra-android-* )
#			filter="${filter},${item}"
#			;;
#		extra-google-* )
#			filter="${filter},${item}"
#			;;
	esac
done

filter=${filter#,}
if test "$filter" = ''; then
	echo 'No update available.'
	if test "$BASH_SOURCE" != "$0"; then
		return 0
	else
		exit 0
	fi
fi

echo 'Update Android SDK...'
expect -c "
set timeout -1
spawn $ANDROID_HOME/tools/android update sdk --filter $filter --no-ui --all
expect { 
	\"Do you accept the license\" { exp_send \"y\r\" ; exp_continue }
	eof
}
"
# --dry-mode

if [[ -d "$build_tools_dir" ]]; then
	for ver in $(ls -1r "$build_tools_dir"); do
		rm -f "$ANDROID_HOME/tools/dexdump"
		ln -s "$build_tools_dir/$ver/dexdump" "$ANDROID_HOME/tools/dexdump"
		rm -f "$ANDROID_HOME/tools/zipalign"
		ln -s "$build_tools_dir/$ver/zipalign" "$ANDROID_HOME/tools/zipalign"
		break
	done
fi
