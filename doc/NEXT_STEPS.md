# Next Steps - IBM COS VMware vCenter Deployment

## Current Status ✅

All implementation work is complete:
- ✅ Packer templates created and built
- ✅ Terraform configuration updated for template-based deployment
- ✅ SSH configuration scripts created
- ✅ Documentation completed
- ✅ `terraform plan` validated successfully

## Immediate Next Steps

### Option 1: Deploy the Infrastructure Now

If you're ready to deploy, run:

```bash
cd /Users/olemyk/Documents/github-local/ibm-cos-vm-iac-vcenter
terraform apply
```

**What will happen:**
1. Terraform will show the plan (21 resources to add)
2. Type `yes` to confirm
3. Deployment will take ~25 minutes:
   - Manager VM: Clone + reconfigure to 10.33.3.203 (~5 min)
   - Accesser VM: Clone + reconfigure to 10.33.3.204 + connect to Manager (~5 min)
   - Slicestor 1: Clone + reconfigure to 10.33.3.205 + connect to Manager (~5 min)
   - Slicestor 2: Clone + reconfigure to 10.33.3.206 + connect to Manager (~5 min)
   - Slicestor 3: Clone + reconfigure to 10.33.3.207 + connect to Manager (~5 min)

**After deployment:**
- Access Manager UI: https://10.33.3.203
- Default credentials: localadmin / password
- Complete first-time setup per IBM documentation

### Option 2: Review Configuration First

Before deploying, you may want to review:

```bash
# Review the deployment plan in detail
terraform plan -out=tfplan

# Review current configuration
cat terraform.tfvars

# Verify templates exist
govc ls /TEC/vm/Templates

# Test SSH access to templates (if still running)
ssh -i ./packer/packer_rsa localadmin@10.33.3.200 "version"
```

### Option 3: Adjust Configuration

If you need to change any settings before deployment:

**Change IP addresses:**
```bash
vi terraform.tfvars
# Edit base_ip, gateway, dns_servers, etc.
```

**Change number of Slicestors:**
```bash
vi terraform.tfvars
# Change num_slicestors from 3 to 6
```

**Change VM folder:**
```bash
vi terraform.tfvars
# Change vm_folder from "COS-System-1" to something else
```

After changes, run `terraform plan` again to verify.

## Deployment Monitoring

During deployment, you can monitor progress:

**In vCenter UI:**
- Navigate to the "COS-System-1" folder
- Watch VMs being created and powered on
- Check Recent Tasks for progress

**In Terminal:**
- Terraform will show progress for each resource
- SSH configuration scripts will output their progress
- Look for "Apply complete!" message at the end

**Expected Output:**
```
Apply complete! Resources: 21 added, 0 changed, 1 destroyed.

Outputs:

accesser_ip = "10.33.3.204"
deployment_summary = {
  "accesser_ip" = "10.33.3.204"
  "cos_version" = "3.17.2.40"
  "manager_ip" = "10.33.3.203"
  "manager_url" = "https://10.33.3.203"
  "num_slicestors" = 3
  "slicestor_ips" = [
    "10.33.3.205",
    "10.33.3.206",
    "10.33.3.207",
  ]
  "system_index" = 1
}
manager_ip = "10.33.3.203"
manager_url = "https://10.33.3.203"
slicestor_ips = [
  "10.33.3.205",
  "10.33.3.206",
  "10.33.3.207",
]
```

## Troubleshooting

If deployment fails:

**SSH Connection Issues:**
```bash
# Verify template IPs are accessible
ping 10.33.3.200
ping 10.33.3.201
ping 10.33.3.202

# Test SSH manually
ssh -i ./packer/packer_rsa localadmin@10.33.3.200
```

**Template Not Found:**
```bash
# Verify templates exist
govc ls /TEC/vm/Templates

# Rebuild if needed
cd packer
./build-all-templates.sh
```

**IP Conflict:**
```bash
# Check if IPs are already in use
ping 10.33.3.203
ping 10.33.3.204
ping 10.33.3.205

# Change base_ip in terraform.tfvars if needed
```

**Review Logs:**
```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply
```

## Post-Deployment Tasks

After successful deployment:

### 1. Access Manager UI
```bash
open https://10.33.3.203
# Or visit in browser
```

### 2. Complete First-Time Setup
Follow IBM COS documentation:
- https://www.ibm.com/docs/en/coss/3.20.1?topic=administration-first-time-setup

### 3. Verify All Nodes
```bash
# SSH to each node and check version
ssh -i ./packer/packer_rsa localadmin@10.33.3.203 "version"  # Manager
ssh -i ./packer/packer_rsa localadmin@10.33.3.204 "version"  # Accesser
ssh -i ./packer/packer_rsa localadmin@10.33.3.205 "version"  # Slicestor 1
ssh -i ./packer/packer_rsa localadmin@10.33.3.206 "version"  # Slicestor 2
ssh -i ./packer/packer_rsa localadmin@10.33.3.207 "version"  # Slicestor 3
```

### 4. Configure Storage Pools
In Manager UI:
- Navigate to Storage → Pools
- Create storage pools using Slicestor data disks
- Configure replication and erasure coding

### 5. Create Vaults and Buckets
In Manager UI:
- Navigate to Vaults
- Create vaults for different tenants/applications
- Create buckets within vaults

### 6. Test S3 Access
```bash
# Configure AWS CLI to use Accesser endpoint
aws configure set aws_access_key_id YOUR_ACCESS_KEY
aws configure set aws_secret_access_key YOUR_SECRET_KEY
aws configure set default.region us-east-1

# Test S3 operations
aws s3 --endpoint-url https://10.33.3.204 ls
aws s3 --endpoint-url https://10.33.3.204 mb s3://test-bucket
aws s3 --endpoint-url https://10.33.3.204 cp test.txt s3://test-bucket/
```

## Future Deployments

To deploy additional COS systems:

### Deploy System 2
```bash
# Edit terraform.tfvars
vm_folder = "COS-System-2"
base_ip   = "10.33.3.213"  # Different IP range

# Deploy
terraform apply
```

### Deploy System 3
```bash
# Edit terraform.tfvars
vm_folder = "COS-System-3"
base_ip   = "10.33.3.223"  # Different IP range

# Deploy
terraform apply
```

Each system uses the same Packer templates but deploys to different folders with different IPs.

## Cleanup

To remove the deployment:

```bash
# Destroy all resources
terraform destroy

# Type 'yes' to confirm
```

This will:
- Delete all VMs
- Remove the VM folder
- Preserve Packer templates for future use

## Documentation References

- **Main README**: `README.md` - Complete deployment guide
- **Packer Guide**: `packer/README.md` - Template building
- **Integration Guide**: `doc/PACKER_TERRAFORM_INTEGRATION.md` - Technical deep-dive
- **Troubleshooting**: `README.md` - Troubleshooting section

## Support

For issues or questions:
1. Check the troubleshooting section in README.md
2. Review the comprehensive documentation
3. Check Terraform and Packer logs
4. Verify vCenter tasks and events

---

**Ready to deploy?** Run `terraform apply` to start! 🚀