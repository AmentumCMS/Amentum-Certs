# Amentum-Certs — Copilot Instructions

## Repository Purpose

This repository builds and distributes **Amentum root CA certificates** as native Linux
packages. It produces:

- **RPM** packages for RHEL, CentOS, Rocky Linux, and Alma Linux
- **DEB** packages for Debian and Ubuntu

Packages install root certificates into the operating system trust store and invoke the
appropriate trust-refresh command (`update-ca-trust` / `update-ca-certificates`) so that
tools like `curl`, `openssl`, and browsers immediately trust Amentum-issued TLS
certificates after installation.

---

## Repository Layout

```
.
├── certs/                        # Root CA certificate files (.crt / .pem)
│   └── .gitkeep                  # Keeps the directory tracked when empty
├── scripts/
│   ├── build-rpm.sh              # Dynamically generates an RPM spec and runs rpmbuild
│   └── build-deb.sh              # Creates Debian package layout and runs dpkg-deb
├── .github/
│   ├── copilot-instructions.md   # This file
│   ├── dependabot.yml            # Keeps Actions pinned versions up to date
│   └── workflows/
│       ├── build-rpm.yml         # Reusable workflow: build + test RPM
│       ├── build-deb.yml         # Reusable workflow: build + test DEB
│       └── release.yml           # Orchestrates versioned release on push to main
└── README.md
```

---

## Key Conventions

### Certificate Files
- Place root CA files in `certs/` using `.crt` or `.pem` extension.
- Both extensions are supported; `.pem` files are automatically renamed to `.crt` in the
  DEB package (required by `update-ca-certificates`).
- The `certs/` directory may be empty — builds succeed and produce minimal packages
  containing only a `README.txt`.

### Package Versioning
- Versions follow the `YYYYMMDD` date format (e.g., `20240428`).
- The RPM Release field is always `1%{?dist}`.
- The DEB Architecture field is always `all`.

### Trust Store Paths

| Distribution family | Certificate path |
|---|---|
| RPM (RHEL/CentOS/Rocky/Alma) | `/etc/pki/ca-trust/source/anchors/` |
| DEB (Debian/Ubuntu) | `/usr/local/share/ca-certificates/amentum/` |
| APK (Alpine Linux) | `/usr/share/ca-certificates/amentum/` |

### Build Scripts
- `scripts/build-rpm.sh [VERSION]` — generates a spec file dynamically from the
  contents of `certs/`, then calls `rpmbuild`. Must be run inside an RPM-capable
  environment (Rocky Linux 9 container in CI).
- `scripts/build-deb.sh [VERSION]` — creates the Debian package directory tree, then
  calls `dpkg-deb`. Runs on the Ubuntu GitHub-hosted runner.

### Workflows
- `build-rpm.yml` and `build-deb.yml` are **reusable** (`workflow_call`) and also
  trigger on **pull requests** to `main`.
- `release.yml` triggers on every **push to `main`** and on manual dispatch. It calls
  both reusable workflows, then publishes a GitHub release tagged `YYYYMMDD`.
- If a release for today already exists, `release.yml` updates the assets in-place
  using `gh release upload --clobber`.

---

## Common Tasks

### Adding a Certificate
1. Copy the `.crt` or `.pem` file into `certs/`.
2. Commit and push to `main`.
3. The `release.yml` workflow will automatically build and publish a new release.

### Triggering a Manual Release
Use the **workflow_dispatch** trigger on `release.yml` in the GitHub Actions UI.
Optionally supply a `version` input to override the default `YYYYMMDD` tag.

### Local Build (RPM)
```bash
# Requires: rpm-build, rpmdevtools (dnf install -y rpm-build rpmdevtools)
./scripts/build-rpm.sh
```

### Local Build (DEB)
```bash
# Requires: dpkg-dev (apt-get install -y dpkg-dev)
./scripts/build-deb.sh
```

### Verifying Installed Trust (RPM)
```bash
# List files owned by the package
rpm -ql amentum-certs

# Check the trust store
trust list --filter=ca-anchors | grep -i amentum
```

### Verifying Installed Trust (DEB)
```bash
# List installed cert files
ls /usr/local/share/ca-certificates/amentum/

# Re-run trust update and check output
sudo update-ca-certificates --fresh 2>&1
```

---

## CI/CD Expectations
- All builds run in ephemeral containers/VMs — no persistent state between runs.
- `actions/upload-artifact` and `actions/download-artifact` are used to pass packages
  between jobs in the same workflow run.
- Dependabot keeps all `uses:` action pins updated weekly.
