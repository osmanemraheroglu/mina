#!/bin/bash

# Script builds the debian package for the test_executive

set -euo pipefail

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
cd "${SCRIPTPATH}/../_build"

GITHASH=$(git rev-parse --short=7 HEAD)
GITHASH_CONFIG=$(git rev-parse --short=8 --verify HEAD)

set +u
BUILD_NUM=${BUILDKITE_BUILD_NUM}
BUILD_URL=${BUILDKITE_BUILD_URL}
set -u

# Load in env vars for githash/branch/etc.
source "${SCRIPTPATH}/../buildkite/scripts/export-git-env-vars.sh"

cd "${SCRIPTPATH}/../_build"

BUILDDIR="deb_build"

##################################### GENERATE TEST_EXECUTIVE PACKAGE #######################################

mkdir -p "${BUILDDIR}/DEBIAN"
cat << EOF > "${BUILDDIR}/DEBIAN/control"

Package: mina-test-executive
Version: ${MINA_DEB_VERSION}
License: Apache-2.0
Vendor: none
Architecture: amd64
Maintainer: o(1)Labs <build@o1labs.org>
Installed-Size:
Depends: libjemalloc2, python3, nodejs, yarn, google-cloud-sdk, kubectl, google-cloud-sdk-gke-gcloud-auth-plugin, terraform, helm
Section: base
Priority: optional
Homepage: https://minaprotocol.com/
Description: Tool to run automated tests against a full mina testnet with multiple nodes.
 Built from ${GITHASH} by ${BUILD_URL}
EOF

echo "------------------------------------------------------------"
echo "Control File:"
cat "${BUILDDIR}/DEBIAN/control"

# Binaries
rm -rf "${BUILDDIR}/usr/local/bin"
mkdir -p "${BUILDDIR}/usr/local/bin"
cp ./default/src/app/test_executive/test_executive.exe "${BUILDDIR}/usr/local/bin/mina-test-executive"


# echo contents of deb
echo "------------------------------------------------------------"
echo "Deb Contents:"
find "${BUILDDIR}"

# Build the package
echo "------------------------------------------------------------"
fakeroot dpkg-deb --build "${BUILDDIR}" mina-test-executive-${MINA_DEB_VERSION}.deb
ls -lh mina*.deb

