#!/bin/sh

set -e

TARGET_ARCH="$1"
SUDO_APK=abuild-apk

# get abuild configurables
[ -e /usr/share/abuild/functions.sh ] || (echo "abuild not found" ; exit 1)
CBUILDROOT="$(CTARGET=$TARGET_ARCH . /usr/share/abuild/functions.sh ; echo $CBUILDROOT)"
. /usr/share/abuild/functions.sh
[ -z "$CBUILD_ARCH" ] && die "abuild is too old (use 2.29.0 or later)"
[ -z "$CBUILDROOT" ] && die "CBUILDROOT not set for $TARGET_ARCH"

# deduce aports directory
[ -z "$APORTS" ] && APORTS=$(realpath $(dirname $0)/../)
[ -e "$APORTS/main/build-base" ] || die "Unable to deduce aports base checkout"

apkbuildname() {
	local repo="${1%%/*}"
	local pkg="${1##*/}"
	[ "$repo" = "$1" ] && repo="main"
	echo $APORTS/$repo/$pkg/APKBUILD
}

msg() {
	[ -n "$quiet" ] && return 0
	local prompt="$GREEN>>>${NORMAL}"
	local name="${BLUE}bootstrap-${TARGET_ARCH}${NORMAL}"
        printf "${prompt} ${name}: %s\n" "$1" >&2
}

if [ -z "$TARGET_ARCH" ]; then
	program=$(basename $0)
	cat <<EOF
usage: $program TARGET_ARCH
EOF
	return 1
fi

# ordered cross-build
for PKG in libsodium zeromq; do

	CHOST=$TARGET_ARCH BOOTSTRAP=bootimage APKBUILD=$(apkbuildname $PKG) abuild -r
	target_pkgs=$(CHOST=$TARGET_ARCH BOOTSTRAP=bootimage APKBUILD=$(apkbuildname $PKG) abuild listpkg)
	for target_pkg in $target_pkgs; do
		${SUDO_APK} --update --root "$CBUILDROOT" --repository "$REPODEST/main" add ${target_pkg%%-[0-9]*}
	done
done
