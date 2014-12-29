#!/bin/bash -e

function testIsInstalled() {
	hash $1 2>/dev/null
	if [ $? -eq 1 ]; then
		echo >&2 "ERROR - $1 is not installed or not in your PATH"; exit 1;
	fi
}

## CHECK PREREQUISITES
set +e
testIsInstalled git
testIsInstalled java
set -e

M2_HOME="${PWD}/apache-maven-3.1.1"
DEPLOYER_HOME="${PWD}/maven-android-sdk-deployer"


shell_dir=$(dirname ${BASH_SOURCE:-$0})

set +e
source "$shell_dir/android-sdk-update.bash"
if [ $? != 0 ]; then
	exit $?
fi
set -e

echo "Validating Android SDK - $ANDROID_HOME"
filter=''

# sources
results=$("$ANDROID_HOME/tools/android" list sdk --extended --all --no-ui)
list=$(echo "$results" | grep 'id:' | cut -d \" -f2)
for item in ${list}; do
	case "$item" in
		source-* )
			ver=$(echo "$item" | sed 's/source-//g')
			if [[ ! -d "$ANDROID_HOME/sources/android-$ver" ]]; then
				filter="${filter},${item}"
			fi
			;;
	esac
done

# others
results=$("$ANDROID_HOME/tools/android" list sdk --extended --no-ui)
list=$(echo "$results" | grep 'id:' | cut -d \" -f2)
for item in ${list}; do
	case "$item" in
		extra-android-* )
			filter="${filter},${item}"
			;;
		extra-google-* )
			filter="${filter},${item}"
			;;
	esac
done

filter=${filter#,}
if test "$filter" != ''; then
	echo 'Update Android SDK...'
	"$ANDROID_HOME/tools/android" update sdk --filter $filter --no-ui --all
fi

# Apache Maven
if [[ ! -d "$M2_HOME" ]]; then
	echo 'Downloading Apache Maven'
	status=$(curl --ipv4 --location --output "$PWD/apache-maven-3.1.1-bin.zip" --silent --write-out '%{http_code}' http://archive.apache.org/dist/maven/maven-3/3.1.1/binaries/apache-maven-3.1.1-bin.zip)
	if test "$status" != '200'; then
		echo "ERROR - Download failed: $status"
		exit 1
	fi
	set +e
	unzip "$PWD/apache-maven-3.1.1-bin.zip"
	set -e
	if test "$PWD/apache-maven-3.1.1" != "$M2_HOME"; then
		mv "$PWD/apache-maven-3.1.1" "$M2_HOME"
	fi
fi

# Maven Android SDK Deployer
if [[ ! -d "$DEPLOYER_HOME" ]]; then
	set +x
	git --version
	git clone --single-branch -b master https://github.com/simpligility/maven-android-sdk-deployer "$DEPLOYER_HOME"
	set -x
fi

# Local deploy
cd "$DEPLOYER_HOME"
"$M2_HOME/bin/mvn" -e install

# In-House deploy

