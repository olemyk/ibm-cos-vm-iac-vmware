# IBM Cloud Object Storage OVA Files

This directory should contain the IBM Cloud Object Storage OVA image files.

## Required Files

Download the following OVA files from [IBM Fix Central](https://www.ibm.com/support/fixcentral/) and place them in this directory:

- `clevos-<version>-manager.ova`
- `clevos-<version>-accesser.ova`
- `clevos-<version>-slicestor.ova`

For example, for version 3.17.2.40:
- `clevos-3.17.2.40-manager.ova`
- `clevos-3.17.2.40-accesser.ova`
- `clevos-3.17.2.40-slicestor.ova`

## Optional Files

You may also download the MD5 checksum files to verify the integrity of your downloads:
- `clevos-<version>-manager.ova.md5`
- `clevos-<version>-accesser.ova.md5`
- `clevos-<version>-slicestor.ova.md5`

## Authorization

Access to IBM Cloud Object Storage downloads may require authorization. Contact your IBM representative if you need assistance obtaining these files.

## Version Configuration

Make sure the version specified in your `terraform.tfvars` file matches the version of the OVA files you have downloaded.