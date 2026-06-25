# Multiple Accesser Support

## Overview

The IBM COS deployment now supports deploying multiple Accesser nodes with sequential deployment to avoid IP conflicts during network reconfiguration.

## Changes Made

### 1. Added `num_accessers` Variable

**File**: `variables.tf`

```hcl
variable "num_accessers" {
  description = "Number of Accesser nodes (1-3)"
  type        = number
  default     = 1

  validation {
    condition     = var.num_accessers >= 1 && var.num_accessers <= 3
    error_message = "Number of Accessers must be between 1 and 3."
  }
}
```

### 2. Updated IP Allocation Logic

**File**: `main.tf` - locals block

Changed from single `accesser_ip` to array `accesser_ips`:

```hcl
locals {
  # Calculate IPs sequentially: Manager, Accesser1, Accesser2, ..., Slicestor1, Slicestor2, ...
  manager_ip    = var.base_ip
  accesser_ips  = [
    for i in range(var.num_accessers) :
    "${local.ip_prefix}.${local.ip_suffix + 1 + i}"
  ]
  
  slicestor_ips = [
    for i in range(var.num_slicestors) :
    "${local.ip_prefix}.${local.ip_suffix + 1 + var.num_accessers + i}"
  ]
}
```

### 3. Refactored Accesser Deployment

**File**: `main.tf`

Replaced single `module "cos_accesser"` with three separate modules:
- `module "cos_accesser_1"` - deploys after Manager
- `module "cos_accesser_2"` - deploys after Accesser 1
- `module "cos_accesser_3"` - deploys after Accesser 2

Each uses `count = var.num_accessers >= N ? 1 : 0` for conditional creation.

### 4. Updated Slicestor Dependencies

**File**: `main.tf`

Slicestor 1 now depends on all Accesser modules:

```hcl
depends_on = [
  module.cos_accesser_1,
  module.cos_accesser_2,
  module.cos_accesser_3
]
```

### 5. Updated Outputs

**File**: `outputs.tf`

Changed from single accesser outputs to arrays:

```hcl
output "accesser_ips" {
  description = "IP addresses of the Accesser VMs"
  value       = local.accesser_ips
}

output "accesser_vm_names" {
  description = "Names of the Accesser VMs"
  value = compact([
    var.num_accessers >= 1 ? module.cos_accesser_1[0].vm_name : "",
    var.num_accessers >= 2 ? module.cos_accesser_2[0].vm_name : "",
    var.num_accessers >= 3 ? module.cos_accesser_3[0].vm_name : "",
  ])
}
```

## IP Address Allocation Examples

### Example 1: 1 Accesser, 3 Slicestors (default)
- Manager: 10.33.3.110
- Accesser 1: 10.33.3.111
- Slicestor 1-3: 10.33.3.112-114

### Example 2: 2 Accessers, 3 Slicestors
- Manager: 10.33.3.110
- Accesser 1-2: 10.33.3.111-112
- Slicestor 1-3: 10.33.3.113-115

### Example 3: 3 Accessers, 6 Slicestors
- Manager: 10.33.3.110
- Accesser 1-3: 10.33.3.111-113
- Slicestor 1-6: 10.33.3.114-119

## Usage

### Deploy with Multiple Accessers

Edit `terraform.tfvars`:

```hcl
num_accessers  = 2  # Deploy 2 Accesser nodes
num_slicestors = 3  # Deploy 3 Slicestor nodes
```

Then deploy:

```bash
terraform apply
```

### Sequential Deployment Timeline

With 2 Accessers and 3 Slicestors:
1. Manager: ~7 minutes
2. Accesser 1: ~7 minutes (after Manager)
3. Accesser 2: ~7 minutes (after Accesser 1)
4. Slicestor 1: ~10 minutes (after all Accessers)
5. Slicestor 2: ~10 minutes (after Slicestor 1)
6. Slicestor 3: ~10 minutes (after Slicestor 2)

**Total**: ~51 minutes

## Benefits

1. **No IP Conflicts**: Sequential deployment ensures only one VM reconfigures its IP at a time
2. **Scalability**: Easy to add more Accessers for increased S3 API capacity
3. **High Availability**: Multiple Accessers provide redundancy for S3 access
4. **Load Balancing**: Distribute S3 API requests across multiple Accessers

## Limitations

- Maximum 3 Accessers (can be increased by adding more module blocks)
- All Accessers must complete before Slicestors start deploying
- Sequential deployment increases total deployment time

## Troubleshooting

### Check Accesser Configuration

```bash
cd ../ibm-cos-vm-iac-vcenter

# Check all Accessers
for i in 1 2 3; do
  ip="10.33.3.11$i"
  echo "=== Checking Accesser $i at $ip ==="
  ssh -i ./packer/packer_rsa -o StrictHostKeyChecking=no localadmin@$ip "version" 2>/dev/null || echo "Not deployed"
done
```

### Verify Manager IP Configuration

```bash
# Create check script
cat > check-accesser-manager.expect << 'EOF'
#!/usr/bin/expect -f
set timeout 10

foreach {num ip} {1 10.33.3.111 2 10.33.3.112 3 10.33.3.113} {
    puts "\n=== Checking Accesser $num at $ip ==="
    
    spawn ssh -i ./packer/packer_rsa -o StrictHostKeyChecking=no localadmin@$ip
    
    expect {
        -re "#|>" {
            send "manager\r"
            expect -re "#|>"
            puts $expect_out(buffer)
            send "exit\r"
            expect eof
        }
        timeout { puts "Connection timeout" }
    }
}
EOF

chmod +x check-accesser-manager.expect
./check-accesser-manager.expect