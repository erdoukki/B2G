#!/bin/bash

REPO=${REPO:-./repo}
sync_flags=""

repo_sync() {
	rm -rf .repo/manifest* &&
	$REPO init -u $GITREPO -b $BRANCH -m $1.xml $REPO_INIT_FLAGS &&
	$REPO sync $sync_flags $REPO_SYNC_FLAGS
	ret=$?
	if [ "$GITREPO" = "$GIT_TEMP_REPO" ]; then
		rm -rf $GIT_TEMP_REPO
	fi
	if [ $ret -ne 0 ]; then
		echo Repo sync failed
		exit -1
	fi
}

case `uname` in
"Darwin")
	# Should also work on other BSDs
	CORE_COUNT=`sysctl -n hw.ncpu`
	;;
"Linux")
	CORE_COUNT=`grep processor /proc/cpuinfo | wc -l`
	;;
*)
	echo Unsupported platform: `uname`
	exit -1
esac

GITREPO=${GITREPO:-"http://github.com/gp-b2g/b2g-manifest.git"}
BRANCH=${BRANCH:-master}

while [ $# -ge 1 ]; do
	case $1 in
	-d|-l|-f|-n|-c|-q|-j*)
		sync_flags="$sync_flags $1"
		if [ $1 = "-j" ]; then
			shift
			sync_flags+=" $1"
		fi
		shift
		;;
	--help|-h)
		# The main case statement will give a usage message.
		break
		;;
	-*)
		echo "$0: unrecognized option $1" >&2
		exit 1
		;;
	*)
		break
		;;
	esac
done

GIT_TEMP_REPO="tmp_manifest_repo"
if [ -n "$2" ]; then
	GITREPO=$GIT_TEMP_REPO
	rm -rf $GITREPO &&
	git init $GITREPO &&
	cp $2 $GITREPO/$1.xml &&
	cd $GITREPO &&
	git add $1.xml &&
	git commit -m "manifest" &&
	git branch -m $BRANCH &&
	cd ..
fi

echo MAKE_FLAGS=-j$((CORE_COUNT + 2)) > .tmp-config
echo GECKO_OBJDIR=$PWD/objdir-gecko >> .tmp-config
echo DEVICE_NAME=$1 >> .tmp-config

case "$1" in	
"peak")
	echo DEVICE=peak >> .tmp-config &&
	repo_sync $1
	;;
	
"keon")
	echo DEVICE=keon >> .tmp-config &&
	repo_sync $1
	;;

"revolution")
	echo DEVICE=revolution >> .tmp-config &&
	echo PRODUCT_NAME=revolution >> .tmp-config &&
	echo B2G_SYSTEM_APPS=1 >> .tmp-config &&
	repo_sync $1
	;;
*)
	echo "Usage: $0 [-cdflnq] (device name)"
	echo "Flags are passed through to |./repo sync|."
	echo
	echo Valid devices to configure are:
	echo - peak
	echo - keon
	echo - revolution
	exit -1
	;;
esac

if [ $? -ne 0 ]; then
	echo Configuration failed
	exit -1
fi

mv .tmp-config .config

echo Run \|./build.sh\| to start building
