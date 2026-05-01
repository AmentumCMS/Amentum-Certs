# Amentum-Certs

Linux package repository for distributing **Amentum root CA certificates**.

Provides pre-built **RPM** (RHEL / CentOS / Rocky Linux / Alma Linux), **DEB**
(Debian / Ubuntu), and **APK** (Alpine Linux) packages that install Amentum root
certificates into the operating system certificate trust store and automatically
refresh it.

---

## Download & Install

Packages are published automatically on every push to `main` using date-based
versioning (`YYYYMMDD`). Download the latest from the
[Releases](../../releases/latest) page, or use the one-liner commands below to
fetch and install in a single step.

### RHEL / CentOS / Rocky Linux / Alma Linux

#### Option A: Use the hosted YUM repository (recommended)

```bash
# Add the Amentum repository (includes GPG key verification)
sudo curl -o /etc/yum.repos.d/amentum-certs.repo \
  https://amentumcms.github.io/Amentum-Certs/yum/amentum-certs.repo

# Install the package (GPG signature is verified automatically)
sudo dnf install amentum-certs

# Verify installed certificates
trust list --filter=ca-anchors | grep -i amentum
```

#### Option B: Install directly from GitHub Releases

```bash
# Download and install the latest release in one step
VERSION=$(curl -fsSL -o /dev/null -w '%{url_effective}' \
  https://github.com/AmentumCMS/Amentum-Certs/releases/latest \
  | sed 's|.*/tag/||') \
  && curl -fsSLO \
    "https://github.com/AmentumCMS/Amentum-Certs/releases/download/${VERSION}/amentum-certs-${VERSION}-1.noarch.rpm" \
  && sudo rpm -ivh "amentum-certs-${VERSION}-1.noarch.rpm"

# Verify installed certificates
trust list --filter=ca-anchors | grep -i amentum
```

### Debian / Ubuntu

```bash
# Download and install the latest release in one step
VERSION=$(curl -fsSL -o /dev/null -w '%{url_effective}' \
  https://github.com/AmentumCMS/Amentum-Certs/releases/latest \
  | sed 's|.*/tag/||') \
  && curl -fsSLO \
    "https://github.com/AmentumCMS/Amentum-Certs/releases/download/${VERSION}/amentum-certs_${VERSION}_all.deb" \
  && sudo dpkg -i "amentum-certs_${VERSION}_all.deb"

# Verify installed certificates
ls /usr/local/share/ca-certificates/amentum/
```

### Alpine Linux

```bash
# Download and install the latest release in one step
VERSION=$(curl -fsSL -o /dev/null -w '%{url_effective}' \
  https://github.com/AmentumCMS/Amentum-Certs/releases/latest \
  | sed 's|.*/tag/||') \
  && curl -fsSLO \
    "https://github.com/AmentumCMS/Amentum-Certs/releases/download/${VERSION}/amentum-certs-${VERSION}-r0.apk" \
  && sudo apk add --allow-untrusted "amentum-certs-${VERSION}-r0.apk"

# Verify installed certificates
ls /usr/share/ca-certificates/amentum/
```

---

## Package Signing

### Current signing state

| Package | Signed | Notes |
|---------|--------|-------|
| RPM | **Yes** | Packages and YUM repo metadata are GPG-signed. Public key published at the repository URL. |
| DEB | No | Individual `.deb` files are unsigned. Verify the download source via HTTPS. |
| APK | CI ephemeral key | Each CI run generates a fresh RSA key; no persistent public key is distributed. |

### RPM GPG Verification

RPM packages are signed with the Amentum GPG key. When using the hosted YUM repository
(see "Option A" above), the GPG key is imported automatically. To manually import the key:

```bash
# Import the Amentum RPM signing key
sudo rpm --import https://amentumcms.github.io/Amentum-Certs/yum/RPM-GPG-KEY-amentum

# Verify a downloaded package
rpm --checksig amentum-certs-*.rpm
```

### Repository Setup (required secrets)

To enable GPG signing in CI, configure the following repository secrets:

| Secret | Description |
|--------|-------------|
| `GPG_PRIVATE_KEY` | ASCII-armored GPG private key used for signing |
| `GPG_PASSPHRASE` | Passphrase for the GPG private key |

If these secrets are not configured, packages will be built without signatures (same
behavior as before).

### Trusting the APK signing key (optional)

If you want `apk add` to verify the package signature without `--allow-untrusted`, export
the public key from the CI build log (it is printed by `abuild-keygen`) and install it:

```sh
# Copy the .rsa.pub key printed during the CI build to /etc/apk/keys/
cp amentum-ci.rsa.pub /etc/apk/keys/
apk add amentum-certs-<VERSION>-r0.apk
```

---

## Certificate Trust Store Paths

| Distribution | Installed path |
|---|---|
| RHEL / CentOS / Rocky Linux / Alma Linux | `/etc/pki/ca-trust/source/anchors/` |
| Debian / Ubuntu | `/usr/local/share/ca-certificates/amentum/` |
| Alpine Linux | `/usr/share/ca-certificates/amentum/` |

The appropriate trust refresh command (`update-ca-trust extract` or
`update-ca-certificates`) is executed automatically as a package post-install scriptlet.

---

## Managing Certificates

### Adding a Certificate

1. Place a `.crt` or `.pem` root CA file in the `certs/` directory.
2. Commit and push to `main`.
3. The `release.yml` workflow builds and publishes updated packages automatically.

> **Note:** `.pem` files are renamed to `.crt` inside the DEB package because
> `update-ca-certificates` requires the `.crt` extension.

---

## Workflows

| Workflow | Trigger | Description |
|---|---|---|
| `build-rpm.yml` | Pull request to `main`, `workflow_call` | Builds and tests the RPM package inside a Rocky Linux 9 container |
| `build-deb.yml` | Pull request to `main`, `workflow_call` | Builds and tests the DEB package on an Ubuntu runner |
| `build-apk.yml` | Pull request to `main`, `workflow_call` | Builds and tests the APK package inside an Alpine Linux container |
| `release.yml` | Push to `main`, manual dispatch | Calls all three build workflows and publishes a `YYYYMMDD`-tagged GitHub release |

### Test Output

Each build workflow installs the produced package and prints only the Amentum
certificates that were added to the system trust store, confirming end-to-end
trust propagation:

- **RPM:** `trust list --filter=ca-anchors | grep -i amentum`
- **DEB:** `ls /usr/local/share/ca-certificates/amentum/` and `update-ca-certificates --fresh`
- **APK:** `ls /usr/share/ca-certificates/amentum/` and `update-ca-certificates`

---

## Package Details

| Field | Value |
|---|---|
| Package name | `amentum-certs` |
| Version format | `YYYYMMDD` |
| RPM architecture | `noarch` |
| DEB architecture | `all` |
| APK architecture | `noarch` |
| RPM post-install command | `update-ca-trust extract` |
| DEB post-install command | `update-ca-certificates` |
| APK post-install command | `update-ca-certificates` |

---

## Local Development

### Build RPM (requires Rocky Linux / RHEL / CentOS)

```bash
sudo dnf install -y rpm-build rpmdevtools
./scripts/build-rpm.sh          # uses today's date as version
./scripts/build-rpm.sh 20240428 # explicit version
```

### Build DEB (requires Debian / Ubuntu)

```bash
sudo apt-get install -y dpkg-dev
./scripts/build-deb.sh          # uses today's date as version
./scripts/build-deb.sh 20240428 # explicit version
```

### Build APK (requires Alpine Linux)

```bash
# Requires alpine-sdk and an abuild signing key
apk add alpine-sdk
abuild-keygen -a -i -n          # generate and install a signing key (one-time)
./scripts/build-apk.sh          # uses today's date as version
./scripts/build-apk.sh 20240428 # explicit version
```

---

## License

Proprietary — Amentum. All rights reserved.
