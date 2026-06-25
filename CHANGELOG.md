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

[Unreleased]: https://github.com/olemyk/ibm-cos-vm-iac-vcenter/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/olemyk/ibm-cos-vm-iac-vcenter/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/olemyk/ibm-cos-vm-iac-vcenter/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/olemyk/ibm-cos-vm-iac-vcenter/releases/tag/v1.0.0
