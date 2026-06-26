#
# Copyright 2024- IBM Inc. All rights reserved
# SPDX-License-Identifier: Apache2.0
#

terraform {
  required_version = ">= 1.15"

  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.12"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.3"
    }
  }
}