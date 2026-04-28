#!/usr/bin/env bash
# Build script for the amentum-certs APK package (Alpine Linux).
# Usage: ./scripts/build-apk.sh [VERSION]
#   VERSION defaults to today's date in YYYYMMDD format.
# Prerequisites:
#   - alpine-sdk installed (apk add alpine-sdk)
#   - RSA signing key generated (abuild-keygen -a -i -n)
#   - ABUILD_ALLOW_ROOT=1 set in the environment when running as root
set -euo pipefail

ORIG_DIR="${PWD}"
VERSION="${1:-$(date +%Y%m%d)}"
PACKAGE_NAME="amentum-certs"
BUILD_ROOT="$(mktemp -d)"
APORT_DIR="${BUILD_ROOT}/aports/${PACKAGE_NAME}"
export REPODEST="${BUILD_ROOT}/packages"
trap 'rm -rf "${BUILD_ROOT}"' EXIT

echo "Building ${PACKAGE_NAME} APK version ${VERSION}"

mkdir -p "${APORT_DIR}"

# Collect certificate files from the certs/ directory
mapfile -t CERT_FILES < <(find certs -maxdepth 1 \( -name "*.crt" -o -name "*.pem" -o -name "*.cer" \) -type f 2>/dev/null | sort)

echo "Found ${#CERT_FILES[@]} certificate file(s) in certs/"

# Stage processed cert files — update-ca-certificates requires the .crt extension.
# Rename .pem and .cer files to .crt; leave files already ending in .crt unchanged.
CERT_STAGE_DIR="${BUILD_ROOT}/certs-${VERSION}"
mkdir -p "${CERT_STAGE_DIR}"

for cert in "${CERT_FILES[@]}"; do
    fname="$(basename "${cert}")"
    if [[ "${fname}" == *.pem ]]; then
        dest_name="${fname%.pem}.crt"
    elif [[ "${fname}" == *.cer ]]; then
        dest_name="${fname%.cer}.crt"
    else
        dest_name="${fname}"
    fi
    cp "${cert}" "${CERT_STAGE_DIR}/${dest_name}"
    echo "  Staged: ${fname} -> ${dest_name}"
done

# Include a README in the staging dir so it is packed into the source tarball
cat > "${CERT_STAGE_DIR}/README.txt" <<EOF
Amentum Root CA Certificates
Build version: ${VERSION}
Certificates included: ${#CERT_FILES[@]}

APK installs certificates to: /usr/share/ca-certificates/amentum/
Trust store is refreshed automatically via: update-ca-certificates
EOF

# Pack staged certs into a versioned tarball (used as the abuild source)
TARBALL_NAME="certs-${VERSION}.tar.gz"
tar -czf "${APORT_DIR}/${TARBALL_NAME}" -C "${BUILD_ROOT}" "certs-${VERSION}"
SHA512="$(sha512sum "${APORT_DIR}/${TARBALL_NAME}" | awk '{print $1}')"

# Post-install script: refresh the trust store after install/upgrade
cat > "${APORT_DIR}/${PACKAGE_NAME}.post-install" <<'EOF'
#!/bin/sh
update-ca-certificates 2>/dev/null || true
EOF

# Post-deinstall script: refresh the trust store after removal
cat > "${APORT_DIR}/${PACKAGE_NAME}.post-deinstall" <<'EOF'
#!/bin/sh
update-ca-certificates 2>/dev/null || true
EOF

# ---------------------------------------------------------------------------
# Dynamically generate the APKBUILD
# ---------------------------------------------------------------------------
cat > "${APORT_DIR}/APKBUILD" <<APKBUILD
# Maintainer: Amentum <certs@amentum.com>
pkgname="${PACKAGE_NAME}"
pkgver="${VERSION}"
pkgrel=0
pkgdesc="Amentum Root CA Certificates"
url="https://github.com/AmentumCMS/Amentum-Certs"
arch="noarch"
license="Proprietary"
depends="ca-certificates"
options="!check"
install="\${pkgname}.post-install \${pkgname}.post-deinstall"
source="${TARBALL_NAME}"
sha512sums="${SHA512}  ${TARBALL_NAME}"

package() {
    local certdir="\${pkgdir}/usr/share/ca-certificates/amentum"
    install -d "\${certdir}"

    for cert in "\${srcdir}/certs-${VERSION}/"*.crt; do
        [ -f "\${cert}" ] || continue
        install -m 0644 "\${cert}" "\${certdir}/"
    done
}
APKBUILD

echo ""
echo "--- Generated APKBUILD ---"
cat "${APORT_DIR}/APKBUILD"
echo "--------------------------"
echo ""

# Build the APK (abuild must run from the APKBUILD directory)
cd "${APORT_DIR}"
abuild -r

cd "${ORIG_DIR}"

# Locate the built APK and copy it to the original working directory
APK_FILE="$(find "${REPODEST}" -name "*.apk" -type f | head -1)"
if [[ -z "${APK_FILE}" ]]; then
    echo "ERROR: No APK file found under ${REPODEST}"
    exit 1
fi
cp -v "${APK_FILE}" "${ORIG_DIR}/"

echo ""
echo "Successfully built:"
ls -lh "${ORIG_DIR}/${PACKAGE_NAME}"*.apk
