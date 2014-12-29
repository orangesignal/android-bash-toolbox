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
source "$shell_dir/android-sdk-download.bash"

echo "Validating Android SDK - $ANDROID_HOME"
build_tools_dir="$ANDROID_HOME/build-tools"
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
		build-tools-* )
			filter="${filter},${item}"
			;;
		platform-tools )
			filter="${filter},${item}"
			;;
		android-* )
			filter="${filter},${item}"
			;;
		addon-* )
			filter="${filter},${item}"
			;;
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

	if [[ -d "$build_tools_dir" ]]; then
		for ver in $(ls -1r "$build_tools_dir"); do
			rm -f "$ANDROID_HOME/tools/dexdump"
			ln -s "$build_tools_dir/$ver/dexdump" "$ANDROID_HOME/tools/dexdump"
			rm -f "$ANDROID_HOME/tools/zipalign"
			ln -s "$build_tools_dir/$ver/zipalign" "$ANDROID_HOME/tools/zipalign"
			break
		done
	fi
fi

# Apache Maven
if [[ ! -d "$M2_HOME" ]]; then
	echo 'Downloading Apache Maven'
	ver='3.1.1'
	url="http://archive.apache.org/dist/maven/maven-3/${ver}/binaries/apache-maven-${ver}-bin.zip"
	archive_path="${PWD}/${url##*/}"
	exdir="${PWD}/$(echo "${url##*/}" | sed 's/-bin.zip//g')"
	status=$(curl --ipv4 --location --output "$archive_path" --silent --write-out '%{http_code}' http://archive.apache.org/dist/maven/maven-3/3.1.1/binaries/apache-maven-3.1.1-bin.zip)
	if test "$status" != '200'; then
		echo "ERROR - Download failed: $status"
		exit 1
	fi
	set +e
	unzip "$archive_path"
	set -e
	if test "$exdir" != "$M2_HOME"; then
		rm -rf "$M2_HOME"
		mv "$exdir" "$M2_HOME"
	fi
fi

# Maven Android SDK Deployer
if [[ ! -d "$DEPLOYER_HOME" ]]; then
	set +x
	git --version
	git clone --depth 1 --single-branch -b master https://github.com/simpligility/maven-android-sdk-deployer "$DEPLOYER_HOME"
	set -x
fi

# Local repository deploy
local_repo="$HOME/.m2/repository"
#local_repo="$DEPLOYER_HOME/.m2/repository"
deploy_repo="$DEPLOYER_HOME/m2repository"
if test "$local_repo" = "$deploy_repo"; then
	echo "ERROR - deploy_repo parameter"
	exit 1
fi
"$M2_HOME/bin/mvn" -Dmaven.repo.local="$local_repo" --errors --file "$DEPLOYER_HOME/pom.xml" install

# In-House repository deploy
# $HOME/.m2/settings.xml - Sonatype Nexus OSS example
# <servers>
#   <server>
#     <id>nexus</id>
#     <username>admin</username>
#     <password>admin123</password>
#   </server>
# </servers>
#
deploy_url='http://localhost:8081/nexus/content/repositories/thirdparty/'
server_id='nexus'

function deploy() {
	repo_path="$1"
	escaped_repo_path=$(echo "$repo_path" | sed 's/\//\\\//g')
	for pom in $(find "$repo_path" -type f -name "*.pom"); do
		echo "$pom"
		prefix="${pom%.*}"
		groupId=$(xpath "$pom" "//project/groupId/text()" 2>/dev/null)
		artifactId=$(xpath "$pom" "//project/artifactId/text()" 2>/dev/null)
		version=$(xpath "$pom" "//project/version/text()" 2>/dev/null)
		packaging=$(xpath "$pom" "//project/packaging/text()" 2>/dev/null)
		if test "$packaging" = ''; then
			packaging='jar'
		fi

		# artifact
		file="${prefix}.${packaging}"
		url="${deploy_url%/}$(echo "$file" | sed "s/${escaped_repo_path}//g")"
		status=$(curl --ipv4 --location --output /dev/null --silent --write-out '%{http_code}' $url)
		if test "$status" = '404'; then
			"$M2_HOME/bin/mvn" -e deploy:deploy-file \
				-DpomFile="$pom" \
				-Dfile="$file" \
				-Durl=$deploy_url -DrepositoryId=$server_id
		elif test "$status" != '200'; then
			echo "ERROR - $file upload failed: $status"
			return 1
		fi

		# apklib
		file="${prefix}.apklib"
		if [[ -f "$file" ]]; then
			url="${deploy_url%/}$(echo "$file" | sed "s/${escaped_repo_path}//g")"
			status=$(curl --ipv4 --location --output /dev/null --silent --write-out '%{http_code}' $url)
			if test "$status" = '404'; then
				"$M2_HOME/bin/mvn" -e deploy:deploy-file \
					-DgroupId=$groupId -DartifactId=$artifactId -Dversion=$version \
					-Dfile="$file" -Dpackaging=apklib  -DgeneratePom=false \
					-Durl=$deploy_url -DrepositoryId=$server_id
			elif test "$status" != '200'; then
				echo "ERROR - $file upload failed: $status"
				return 1
			fi
		fi

		# javadoc.jar
		file="${prefix}-javadoc.jar"
		if [[ -f "$file" ]]; then
			url="${deploy_url%/}$(echo "$file" | sed "s/${escaped_repo_path}//g")"
			status=$(curl --ipv4 --location --output /dev/null --silent --write-out '%{http_code}' $url)
			if test "$status" = '404'; then
				"$M2_HOME/bin/mvn" -e deploy:deploy-file \
					-DgroupId=$groupId -DartifactId=$artifactId -Dversion=$version \
					-Dfile="$file" -Dpackaging=jar -Dclassifier=javadoc -DgeneratePom=false \
					-Durl=$deploy_url -DrepositoryId=$server_id
			elif test "$status" != '200'; then
				echo "ERROR - $file upload failed: $status"
				return 1
			fi
		fi

		# sources.jar
		file="${prefix}-sources.jar"
		if [[ -f "$file" ]]; then
			url="${deploy_url%/}$(echo "$file" | sed "s/${escaped_repo_path}//g")"
			status=$(curl --ipv4 --location --output /dev/null --silent --write-out '%{http_code}' $url)
			if test "$status" = '404'; then
				"$M2_HOME/bin/mvn" -e deploy:deploy-file \
					-DgroupId=$groupId -DartifactId=$artifactId -Dversion=$version \
					-Dfile="$file" -Dpackaging=jar -Dclassifier=sources -DgeneratePom=false \
					-Durl=$deploy_url -DrepositoryId=$server_id
			elif test "$status" != '200'; then
				echo "ERROR - $file upload failed: $status"
				return 1
			fi
		fi
	done
}

echo 'Deploying Android Support Repository'
deploy "$ANDROID_HOME/extras/android/m2repository"
echo 'Deploy Google Repository'
deploy "$ANDROID_HOME/extras/google/m2repository"

function copydir() {
	echo "Copying $1 to $2"
	mkdir -p "$2"
	cp -R "$1" "$2"
}

rm -rf "$deploy_repo"
copydir "$local_repo/android" "$deploy_repo"
copydir "$local_repo/com/android/future" "$deploy_repo/com/android"
copydir "$local_repo/com/google/android" "$deploy_repo/com/google"
echo 'Deploying Maven Android SDK Deployer Repository'
deploy "$deploy_repo"
