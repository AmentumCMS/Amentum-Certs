#!/usr/bin/env bash
# Build script for the amentum-certs RPM package.
# Usage: ./scripts/build-rpm.sh [VERSION]
#   VERSION defaults to today's date in YYYYMMDD format.
set -euo pipefail

VERSION="${1:-$(date +%Y%m%d)}"
PACKAGE_NAME="amentum-certs"
BUILD_ROOT="$(mktemp -d)"
trap 'rm -rf "${BUILD_ROOT}"' EXIT

echo "Building ${PACKAGE_NAME} RPM version ${VERSION}"

# Set up rpmbuild directory structure
mkdir -p "${BUILD_ROOT}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

# Collect certificate files from the certs/ directory
mapfile -t CERT_FILES < <(find certs -maxdepth 1 \( -name "*.crt" -o -name "*.pem" \) -type f 2>/dev/null | sort)

echo "Found ${#CERT_FILES[@]} certificate file(s) in certs/"

# Copy cert files to SOURCES so rpmbuild can find them
for cert in "${CERT_FILES[@]}"; do
    cp "${cert}" "${BUILD_ROOT}/SOURCES/"
done

# Always include a README in the package so %files is never empty
cat > "${BUILD_ROOT}/SOURCES/README.txt" <<EOF
Amentum Root CA Certificates
Build version: ${VERSION}
Certificates included: ${#CERT_FILES[@]}

RPM installs certificates to: /etc/pki/ca-trust/source/anchors/
Trust store is refreshed automatically via: update-ca-trust extract
EOF

# ---------------------------------------------------------------------------
# Dynamically generate the RPM spec file
# ---------------------------------------------------------------------------
SPEC_FILE="${BUILD_ROOT}/SPECS/${PACKAGE_NAME}.spec"

cat > "${SPEC_FILE}" <<SPEC
Name:           ${PACKAGE_NAME}
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        Amentum Root CA Certificates
License:        Proprietary
BuildArch:      noarch
Requires(post): ca-certificates

%description
Installs Amentum root CA certificates into the system certificate trust
store on RHEL, CentOS, Rocky Linux, Alma Linux, and other RPM-based
distributions. The post-install scriptlet runs update-ca-trust extract
to refresh the certificate trust database.

%install
install -d %{buildroot}/usr/share/doc/${PACKAGE_NAME}
install -m 0644 %{_sourcedir}/README.txt %{buildroot}/usr/share/doc/${PACKAGE_NAME}/
install -d %{buildroot}/etc/pki/ca-trust/source/anchors
SPEC

# Add one install line per cert
for cert in "${CERT_FILES[@]}"; do
    fname="$(basename "${cert}")"
    echo "install -m 0644 %{_sourcedir}/${fname} %{buildroot}/etc/pki/ca-trust/source/anchors/" \
        >> "${SPEC_FILE}"
done

# Scriptlets + static portion of %files
cat >> "${SPEC_FILE}" <<SPEC

%post
/usr/bin/update-ca-trust extract

%postun
/usr/bin/update-ca-trust extract

%files
/usr/share/doc/${PACKAGE_NAME}/README.txt
SPEC

# Add one %files line per cert
for cert in "${CERT_FILES[@]}"; do
    fname="$(basename "${cert}")"
    echo "/etc/pki/ca-trust/source/anchors/${fname}" >> "${SPEC_FILE}"
done

# Changelog (bash expands the date command; RPM macros are left untouched)
cat >> "${SPEC_FILE}" <<SPEC

%changelog
* $(LC_ALL=C date "+%a %b %d %Y") Amentum <certs@amentum.com> - ${VERSION}-1
- Automated package build with ${#CERT_FILES[@]} certificate(s)
SPEC

echo ""
echo "--- Generated spec file ---"
cat "${SPEC_FILE}"
echo "----------------------------"
echo ""

# Build the RPM
rpmbuild \
    --define "_topdir ${BUILD_ROOT}" \
    -bb "${SPEC_FILE}"

# Copy the built RPM(s) to the current directory
find "${BUILD_ROOT}/RPMS" -name "*.rpm" -exec cp -v {} . \;

echo ""
echo "Successfully built:"
ls -lh "${PACKAGE_NAME}-${VERSION}"*.rpm
