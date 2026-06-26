# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

### Planned
- Remote Terraform state backend (S3 / Terraform Cloud)
- CI/CD pipeline for Packer template rebuilds
- Automated device approval via IBM COS API
- Support for more than 3 Accesser nodes


---

## [1.3.0] – 2025-07-08

### Fixed
- **Terraform provider namespace** (`versions.tf`): migrated vSphere provider
  source from deprecated `hashicorp/vsphere` to the canonical `vmware/vsphere`.
  Eliminates the "provider has moved" warning on every `terraform init`.
- **Child module provider inheritance** (`modules/cos-manager/main.tf`,
  `modules/cos-accesser/main.tf`, `modules/cos-slicestor/main.tf`): added
  `terraform { required_providers { vsphere = { source = "vmware/vsphere" } } }`
  to each module. Without this, Terraform resolved child-module provider
  references to the implicit `hashicorp/vsphere` address, installing both
  providers and triggering the registry warning on every init.
- **Perpetual disk diff on Manager and Accesser** (`modules/cos-manager/main.tf`,
  `modules/cos-accesser/main.tf`): added `thin_provisioned = false` to the boot
  disk block. VMs cloned from thick-provisioned Packer templates report
  `thin_provisioned = false` in vSphere state; without the explicit attribute
  the provider defaulted to `true`, generating a permanent plan diff on every run.
- **Boot disk consistency on Slicestor** (`modules/cos-slicestor/main.tf`):
  same `thin_provisioned = false` fix applied to the boot disk so it is
  consistent with the 12 × thick-provisioned data disks.

### Changed
- **Packer SSH key now read from file** (`packer/cos-manager.pkr.hcl`,
  `packer/cos-accesser.pkr.hcl`, `packer/cos-slicestor.pkr.hcl`): replaced
  the hardcoded RSA public key in `boot_command` with a `locals` block that
  reads `packer_rsa.pub` at build time via `trimspace(file(...))`. Running
  `setup-ssh-key.sh` to generate a new key pair is now sufficient — no manual
  copy-paste into HCL files required. An optional `packer_public_key` variable
  allows CI overrides without touching the file.
- **`packer/setup-ssh-key.sh`**: updated header and output messages to reflect
  that the public key is injected automatically; improved next-steps guidance.
- **`packer/variables.pkrvars.hcl.example`**: added commented-out
  `packer_public_key` entry and a note to run `setup-ssh-key.sh` before building.

### Security
- **Removed `packer/packer_rsa.pub` from git tracking** (`git rm --cached`):
  the file was previously committed despite being a machine-generated secret
  tied to a specific key pair. `.gitignore` already listed it but had no effect
  while the file remained tracked. The key is now untracked and git-ignored.
- **Cleaned up `.gitignore`**: removed seven duplicate `packer/packer_rsa.pub`
  entries and a contradictory "public keys are safe to commit" comment; replaced
  with a single canonical block covering the full Packer key pair
  (`packer_rsa`, `packer_rsa.pub`, `packer_rsa_bck`, `packer_rsa.pub_bck`).

---

## [1.2.0] – 2025-06-25

### Added
- Multiple Accesser node support (`num_accessers` variable, 1–3 nodes)
- Sequential deployment of Accesser nodes to prevent IP conflicts
- `system rekey` step in all configuration scripts to ensure unique device
  fingerprints for cloned VMs
- `doc/` folder structure — all supplementary documentation consolidated

### Changed
- Slicestor 1 `depends_on` updated to wait for all Accesser modules
- IP allocation logic generalised: `accesser_ips` is now a list derived from
  `num_accessers`
- `outputs.tf` updated to expose `accesser_ips` (array) and `accesser_vm_names`
- Root-level Markdown documents moved to `doc/` to keep the project root clean

### Fixed
- Duplicate fingerprint issue when cloning multiple VMs from the same Packer
  template (resolved by `system rekey`)
- `check-manager-ip.expect` and helper scripts added to diagnose connectivity
  after deployment

---

## [1.1.0] – 2025-06-22

### Added
- Full Packer automation for all three IBM COS components:
  - `packer/cos-manager.pkr.hcl`
  - `packer/cos-accesser.pkr.hcl`
  - `packer/cos-slicestor.pkr.hcl`
- `packer/build-all-templates.sh` — single script to build all three templates
- `packer/setup-ssh-key.sh` — generates dedicated Packer RSA key pair
- `packer/variables.pkrvars.hcl.example` — safe-to-commit configuration template
- `doc/ISO-INSTALLATION-ANALYSIS.md` — detailed analysis of ClevOS USB ISO boot
  process with annotated screenshots
- `doc/PACKER_TERRAFORM_INTEGRATION.md` — end-to-end integration guide
- Activation wait tuned to 200 seconds based on real installation measurements
- Network connectivity verification (ping gateway) added to Packer build steps

### Changed
- Terraform modules switched from OVA-based deployment to Packer-template clone
  workflow — removes manual console configuration requirement
- Two-phase configuration per VM: Part 1 changes IP and reboots; Part 2 applies
  DNS / NTP / hostname / Manager registration
- `terraform.tfvars.example` updated with Packer template variable names

### Removed
- Direct OVA `ovf_deploy` blocks from Terraform modules (replaced by template
  clone)

---

## [1.0.0] – 2025-06-19

### Added
- Initial Terraform infrastructure-as-code for IBM Cloud Object Storage on
  VMware vCenter
- Modular design with three reusable Terraform modules:
  - `modules/cos-manager/`
  - `modules/cos-accesser/`
  - `modules/cos-slicestor/`
- `variables.tf` with full variable validation (CPU, memory, disk, IP, counts)
- `outputs.tf` exposing Manager URL, VM IPs, and deployment summary
- `versions.tf` pinning Terraform ≥ 1.0 and vSphere provider ≥ 2.0
- `terraform.tfvars.example` — safe-to-commit example configuration
- Sequential deployment strategy using `depends_on` to avoid IP conflicts
- Slicestor support for 12 × data disks per node (configurable size)
- `scripts/` directory with SSH-based expect scripts for post-deployment
  configuration:
  - `configure-manager.expect`
  - `configure-accesser.expect`
  - `configure-slicestor.expect`
  - `configure-vms.sh` orchestration wrapper
- `ova/README.md` and `iso/README.md` explaining where to obtain binary files
- Apache 2.0 LICENSE

### Notes
- OVA-based deployment requires manual vCenter console configuration for initial
  network setup (documented in `doc/MANUAL_CONFIGURATION.md`)
- See `doc/KVM_VS_VMWARE.md` for differences vs the original KVM-based project

---

[Unreleased]: https://github.com/olemyk/ibm-cos-vm-iac-vcenter/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/olemyk/ibm-cos-vm-iac-vcenter/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/olemyk/ibm-cos-vm-iac-vcenter/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/olemyk/ibm-cos-vm-iac-vcenter/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/olemyk/ibm-cos-vm-iac-vcenter/releases/tag/v1.0.0
