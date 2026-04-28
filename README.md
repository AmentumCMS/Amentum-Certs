# Amentum-Certs

Linux package repository for distributing **Amentum root CA certificates**.

Provides pre-built **RPM** (RHEL / CentOS / Rocky Linux / Alma Linux) and **DEB**
(Debian / Ubuntu) packages that install Amentum root certificates into the operating
system certificate trust store and automatically refresh it.

---

## Download & Install

Packages are published automatically on every push to `main` using date-based
versioning (`YYYYMMDD`). Download the latest from the
[Releases](../../releases/latest) page.

### RHEL / CentOS / Rocky Linux / Alma Linux

```bash
# Replace YYYYMMDD with the release date (e.g., 20240428)
sudo rpm -ivh amentum-certs-YYYYMMDD-1.noarch.rpm

# Verify installed certificates
trust list --filter=ca-anchors | grep -i amentum
```

### Debian / Ubuntu

```bash
# Replace YYYYMMDD with the release date (e.g., 20240428)
sudo dpkg -i amentum-certs_YYYYMMDD_all.deb

# Verify installed certificates
ls /usr/local/share/ca-certificates/amentum/
```

---

## Certificate Trust Store Paths

| Distribution | Installed path |
|---|---|
| RHEL / CentOS / Rocky Linux / Alma Linux | `/etc/pki/ca-trust/source/anchors/` |
| Debian / Ubuntu | `/usr/local/share/ca-certificates/amentum/` |

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
| `release.yml` | Push to `main`, manual dispatch | Calls both build workflows and publishes a `YYYYMMDD`-tagged GitHub release |

### Test Output

Each build workflow installs the produced package and prints only the Amentum
certificates that were added to the system trust store, confirming end-to-end
trust propagation:

- **RPM:** `trust list --filter=ca-anchors | grep -i amentum`
- **DEB:** `ls /usr/local/share/ca-certificates/amentum/` and `update-ca-certificates --fresh`

---

## Package Details

| Field | Value |
|---|---|
| Package name | `amentum-certs` |
| Version format | `YYYYMMDD` |
| RPM architecture | `noarch` |
| DEB architecture | `all` |
| RPM post-install command | `update-ca-trust extract` |
| DEB post-install command | `update-ca-certificates` |

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

---

## License

Proprietary — Amentum. All rights reserved.
