#!/bin/sh
# Usage: build-dpkg.sh [target dir]
# The default target directory is the current directory. If it is not
# supplied and the current directory is not empty, it will issue an error in
# order to avoid polluting the current directory after a test run.
#
# The program will setup the dpkg building environment and ultimately call
# dpkg-buildpackage with the appropiate parameters.
#

# Bail out on errors, be strict
set -ue

# Examine parameters
go_out="$(getopt --options "k:Kb" --longoptions key:,nosign,binary \
    --name "$(basename "$0")" -- "$@")"
test $? -eq 0 || exit 1
eval set -- $go_out

BUILDPKG_KEY=''
BINARY=''

for arg
do
    case "$arg" in
    -- ) shift; break;;
    -k | --key ) shift; BUILDPKG_KEY="-pgpg -k$1"; shift;;
    -K | --nosign ) shift; BUILDPKG_KEY="-uc -us";;
    -b | --binary ) shift; BINARY='-b';;
    esac
done

# Working directory
if test "$#" -eq 0
then
    WORKDIR="$(pwd)"

    # Check that the current directory is not empty
    if test "x$(echo *)" != "x*"
    then
        echo >&2 \
            "Current directory is not empty. Use $0 . to force build in ."
        exit 1
    fi

elif test "$#" -eq 1
then
    WORKDIR="$1"

    # Check that the provided directory exists and is a directory
    if ! test -d "$WORKDIR"
    then
        echo >&2 "$WORKDIR is not a directory"
        exit 1
    fi

else
    echo >&2 "Usage: $0 [target dir]"
    exit 1

fi

SOURCEDIR="$(cd $(dirname "$0"); cd ..; pwd)"
test -e "$SOURCEDIR/Makefile" || exit 2

# Extract version from the Makefile
MYSQL_VERSION="$(grep ^MYSQL_VERSION= "$SOURCEDIR/Makefile" \
    | cut -d = -f 2)"
PERCONA_SERVER_VERSION="$(grep ^PERCONA_SERVER_VERSION= "$SOURCEDIR/Makefile" | cut -d = -f 2)"
PERCONA_INNODB_VERSION="$(echo "$PERCONA_SERVER_VERSION" |
    sed s/rel//)"
PRODUCT="Percona-Server-$MYSQL_VERSION"
DEBIAN_VERSION="$(lsb_release -sc)"

# Build information
export BB_PERCONA_REVISION="$(cd "$SOURCEDIR"; bzr revno)"
export DEB_BUILD_OPTIONS='debug nocheck'
export MYSQL_BUILD_CC='gcc'
export MYSQL_BUILD_CXX='gcc'
export HS_CXX=${HS_CXX:-g++}
export UDF_CXX=${UDF_CXX:-g++}
export MYSQL_BUILD_CFLAGS="-fPIC -Wall -O3 -g -static-libgcc -fno-omit-frame-pointer -DPERCONA_INNODB_VERSION=$PERCONA_INNODB_VERSION"
export MYSQL_BUILD_CXXFLAGS="-O2 -fno-omit-frame-pointer -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fno-exceptions -DPERCONA_INNODB_VERSION=$PERCONA_INNODB_VERSION"

# Prepare sources
(
    cd "$SOURCEDIR"
    make clean all
)

# Build
(
    # Make a copy in workdir and copy debian files
    cd "$WORKDIR"

    rm -rf Percona-Server
    cp -a "$SOURCEDIR/$PRODUCT/" .
    (
        cd "$PRODUCT/"

        # Copy debian files from source
        cp -R "$SOURCEDIR/build/debian" .
        chmod +x debian/rules

        # Update distribution name
        dch -m -D "$DEBIAN_VERSION" --force-distribution -v "$MYSQL_VERSION-$PERCONA_SERVER_VERSION-$BB_PERCONA_REVISION.$DEBIAN_VERSION" 'Update distribution'

        dpkg-buildpackage $BINARY -rfakeroot $BUILDPKG_KEY

    )

    rm -rf "$PRODUCT/"

)
