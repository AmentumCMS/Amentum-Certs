#!/usr/bin/env bash
# Build script for the amentum-certs DEB package.
# Usage: ./scripts/build-deb.sh [VERSION]
#   VERSION defaults to today's date in YYYYMMDD format.
set -euo pipefail

VERSION="${1:-$(date +%Y%m%d)}"
PACKAGE_NAME="amentum-certs"
ARCH="all"
BUILD_ROOT="$(mktemp -d)"
PKG_DIR="${BUILD_ROOT}/${PACKAGE_NAME}_${VERSION}_${ARCH}"
trap 'rm -rf "${BUILD_ROOT}"' EXIT

echo "Building ${PACKAGE_NAME} DEB version ${VERSION}"

# Create Debian package directory structure
mkdir -p "${PKG_DIR}/DEBIAN"
mkdir -p "${PKG_DIR}/usr/local/share/ca-certificates/amentum"
mkdir -p "${PKG_DIR}/usr/share/doc/${PACKAGE_NAME}"

# Collect certificate files from the certs/ directory
mapfile -t CERT_FILES < <(find certs -maxdepth 1 \( -name "*.crt" -o -name "*.pem" \) -type f 2>/dev/null | sort)

echo "Found ${#CERT_FILES[@]} certificate file(s) in certs/"

# Copy certs — update-ca-certificates requires the .crt extension.
# Rename .pem files to .crt; leave files already ending in .crt unchanged.
for cert in "${CERT_FILES[@]}"; do
    fname="$(basename "${cert}")"
    if [[ "${fname}" == *.pem ]]; then
        dest_name="${fname%.pem}.crt"
    else
        dest_name="${fname}"
    fi
    cp "${cert}" "${PKG_DIR}/usr/local/share/ca-certificates/amentum/${dest_name}"
    echo "  Included: ${fname} -> ${dest_name}"
done

# Always include a README so the package is valid even with no certs
cat > "${PKG_DIR}/usr/share/doc/${PACKAGE_NAME}/README.txt" <<EOF
Amentum Root CA Certificates
Build version: ${VERSION}
Certificates included: ${#CERT_FILES[@]}

DEB installs certificates to: /usr/local/share/ca-certificates/amentum/
Trust store is refreshed automatically via: update-ca-certificates
EOF

# Calculate installed size (required field in control)
INSTALLED_SIZE="$(du -sk "${PKG_DIR}" | cut -f1)"

# ---------------------------------------------------------------------------
# Create the DEBIAN/control file
# ---------------------------------------------------------------------------
cat > "${PKG_DIR}/DEBIAN/control" <<CONTROL
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Architecture: ${ARCH}
Maintainer: Amentum <certs@amentum.com>
Installed-Size: ${INSTALLED_SIZE}
Depends: ca-certificates
Section: misc
Priority: optional
Description: Amentum Root CA Certificates
 Installs Amentum root CA certificates into the system certificate trust
 store on Debian, Ubuntu, and other DEB-based distributions. The
 post-install script runs update-ca-certificates to refresh the trust
 database.
CONTROL

# ---------------------------------------------------------------------------
# Create DEBIAN/postinst (runs after install/upgrade)
# ---------------------------------------------------------------------------
cat > "${PKG_DIR}/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
update-ca-certificates
POSTINST
chmod 755 "${PKG_DIR}/DEBIAN/postinst"

# ---------------------------------------------------------------------------
# Create DEBIAN/postrm (runs after remove/purge)
# ---------------------------------------------------------------------------
cat > "${PKG_DIR}/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e
update-ca-certificates
POSTRM
chmod 755 "${PKG_DIR}/DEBIAN/postrm"

# Build the DEB package
dpkg-deb --build --root-owner-group "${PKG_DIR}" .

DEB_FILE="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
echo ""
echo "Successfully built:"
ls -lh "${DEB_FILE}"
