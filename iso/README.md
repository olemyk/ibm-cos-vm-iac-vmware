# ISO Files

This directory holds IBM ClevOS USB ISO installation images.  
**The ISO files are excluded from version control** (see `.gitignore`) because they are large binary files (1–6 GB each).

## Required Files

| File | Size | Component |
|------|------|-----------|
| `clevos-3.20.1.59-allinone-usbiso.iso` | ~5.9 GB | All-in-one (used by Packer) |
| `clevos-3.20.1.59-manager-usbiso.iso` | ~1.6 GB | Manager only |
| `clevos-3.20.1.59-accesser-usbiso.iso` | ~1.6 GB | Accesser only |
| `clevos-3.20.1.59-slicestor-usbiso.iso` | ~1.4 GB | Slicestor only |

## How to Obtain

IBM ClevOS ISO images are available to IBM customers through:

- **IBM Fix Central**: https://www.ibm.com/support/fixcentral/
- **IBM Passport Advantage**: https://www.ibm.com/software/passportadvantage/
- Your IBM account representative

## Usage

After downloading, place the ISO files in this directory and upload the
all-in-one ISO to your vCenter datastore before running Packer:

```bash
govc datastore.upload \
  -ds=<your-datastore> \
  iso/clevos-3.20.1.59-allinone-usbiso.iso \
  iso/clevos-3.20.1.59-allinone-usbiso.iso
```

See [`packer/variables.pkrvars.hcl.example`](../packer/variables.pkrvars.hcl.example)
for the `iso_path` variable that references this file.
