# VPC Architecture for AI Cancer Detection Platform

## Network Topology

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud (ap-south-1)                              │
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    VPC (10.0.0.0/16)                                 │   │
│  │                                                                       │   │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │   │
│  │  │  AZ: ap-south-1a │  │  AZ: ap-south-1b │  │  AZ: ap-south-1c │  │   │
│  │  │                  │  │                  │  │                  │  │   │
│  │  │  ┌────────────┐  │  │  ┌────────────┐  │  │  ┌────────────┐  │  │   │
│  │  │  │  Public    │  │  │  │  Public    │  │  │  │  Public    │  │  │   │
│  │  │  │  Subnet    │  │  │  │  Subnet    │  │  │  │  Subnet    │  │  │   │
│  │  │  │ 10.0.1.0/24│  │  │  │ 10.0.2.0/24│  │  │  │ 10.0.3.0/24│  │  │   │
│  │  │  │            │  │  │  │            │  │  │  │            │  │  │   │
│  │  │  │ ┌────────┐ │  │  │  │ ┌────────┐ │  │  │  │ ┌────────┐ │  │  │   │
│  │  │  │ │  NAT   │ │  │  │  │ │  NAT   │ │  │  │  │ │  NAT   │ │  │  │   │
│  │  │  │ │Gateway │ │  │  │  │ │Gateway │ │  │  │  │ │Gateway │ │  │  │   │
│  │  │  │ └────────┘ │  │  │  │ └────────┘ │  │  │  │ └────────┘ │  │  │   │
│  │  │  │            │  │  │  │            │  │  │  │            │  │  │   │
│  │  │  │ ┌────────┐ │  │  │  │            │  │  │  │            │  │  │   │
│  │  │  │ │  ALB   │ │  │  │  │            │  │  │  │            │  │  │   │
│  │  │  │ └────────┘ │  │  │  │            │  │  │  │            │  │  │   │
│  │  │  └────────────┘  │  │  └────────────┘  │  │  └────────────┘  │  │   │
│  │  │         │        │  │         │        │  │         │        │  │   │
│  │  │  ┌──────▼──────┐ │  │  ┌──────▼──────┐ │  │  ┌──────▼──────┐ │  │   │
│  │  │  │  Private    │ │  │  │  Private    │ │  │  │  Private    │ │  │   │
│  │  │  │  Subnet     │ │  │  │  Subnet     │ │  │  │  Subnet     │ │  │   │
│  │  │  │10.0.11.0/24 │ │  │  │10.0.12.0/24 │ │  │  │10.0.13.0/24 │ │  │   │
│  │  │  │             │ │  │  │             │ │  │  │             │ │  │   │
│  │  │  │ ┌─────────┐ │ │  │  │ ┌─────────┐ │ │  │  │ ┌─────────┐ │ │  │   │
│  │  │  │ │   EKS   │ │ │  │  │ │   EKS   │ │ │  │  │ │   EKS   │ │ │  │   │
│  │  │  │ │  Nodes  │ │ │  │  │ │  Nodes  │ │ │  │  │ │  Nodes  │ │ │  │   │
│  │  │  │ └─────────┘ │ │  │  │ └─────────┘ │ │  │  │ └─────────┘ │ │  │   │
│  │  │  │             │ │  │  │             │ │  │  │             │ │  │   │
│  │  │  │ ┌─────────┐ │ │  │  │ ┌─────────┐ │ │  │  │             │ │  │   │
│  │  │  │ │   RDS   │ │ │  │  │ │   RDS   │ │ │  │  │             │ │  │   │
│  │  │  │ │ Primary │ │ │  │  │ │ Replica │ │ │  │  │             │ │  │   │
│  │  │  │ └─────────┘ │ │  │  │ └─────────┘ │ │  │  │             │ │  │   │
│  │  │  │             │ │  │  │             │ │  │  │             │ │  │   │
│  │  │  │ ┌─────────┐ │ │  │  │ ┌─────────┐ │ │  │  │ ┌─────────┐ │ │  │   │
│  │  │  │ │ Lambda  │ │ │  │  │ │ Lambda  │ │ │  │  │ │ Lambda  │ │ │  │   │
│  │  │  │ └─────────┘ │ │  │  │ └─────────┘ │ │  │  │ └─────────┘ │ │  │   │
│  │  │  └─────────────┘ │  │  └─────────────┘ │  │  └─────────────┘ │  │   │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘  │   │
│  │                                                                       │   │
│  │  ┌─────────────────────────────────────────────────────────────┐    │   │
│  │  │                    VPC Endpoints                             │    │   │
│  │  │  • S3 (Gateway)                                              │    │   │
│  │  │  • DynamoDB (Gateway)                                        │    │   │
│  │  │  • KMS (Interface)                                           │    │   │
│  │  │  • ECR API (Interface)                                       │    │   │
│  │  │  • ECR DKR (Interface)                                       │    │   │
│  │  │  • CloudWatch Logs (Interface)                               │    │   │
│  │  │  • STS (Interface)                                           │    │   │
│  │  └─────────────────────────────────────────────────────────────┘    │   │
│  │                                                                       │   │
│  │  ┌─────────────────┐                                                 │   │
│  │  │ Internet Gateway│                                                 │   │
│  │  └────────┬────────┘                                                 │   │
│  └───────────┼──────────────────────────────────────────────────────────┘   │
│              │                                                               │
└──────────────┼───────────────────────────────────────────────────────────────┘
               │
          ┌────▼────┐
          │Internet │
          └─────────┘
```

## Component Details

### VPC (Virtual Private Cloud)
- **CIDR Block**: 10.0.0.0/16
- **DNS Hostnames**: Enabled
- **DNS Support**: Enabled
- **Tenancy**: Default

### Public Subnets (3 across 3 AZs)
- **Purpose**: NAT Gateways, Application Load Balancers
- **CIDR Blocks**: 10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24
- **Internet Access**: Direct via Internet Gateway
- **Auto-assign Public IP**: Enabled

### Private Subnets (3 across 3 AZs)
- **Purpose**: EKS worker nodes, RDS instances, Lambda functions
- **CIDR Blocks**: 10.0.11.0/24, 10.0.12.0/24, 10.0.13.0/24
- **Internet Access**: Outbound only via NAT Gateway
- **Auto-assign Public IP**: Disabled

### Internet Gateway
- **Purpose**: Provides internet access to public subnets
- **Attached to**: VPC

### NAT Gateways (3, one per AZ)
- **Purpose**: Provides outbound internet access for private subnets
- **Placement**: One in each public subnet
- **High Availability**: Yes (one per AZ)
- **Elastic IPs**: 3 (one per NAT Gateway)

### Route Tables

#### Public Route Table
- **Routes**:
  - 10.0.0.0/16 → local
  - 0.0.0.0/0 → Internet Gateway
- **Associated Subnets**: All public subnets

#### Private Route Tables (3, one per AZ)
- **Routes**:
  - 10.0.0.0/16 → local
  - 0.0.0.0/0 → NAT Gateway (specific to AZ)
- **Associated Subnets**: Corresponding private subnet

### VPC Endpoints

#### Gateway Endpoints (No additional cost)
- **S3**: Private access to S3 buckets
- **DynamoDB**: Private access to DynamoDB tables

#### Interface Endpoints (Charged per hour + data transfer)
- **KMS**: Encryption key management
- **ECR API**: Container registry API
- **ECR DKR**: Container image pulls
- **CloudWatch Logs**: Log streaming
- **STS**: IAM role assumption

## Traffic Flow

### Inbound Traffic (Internet → Application)
1. Internet → Internet Gateway
2. Internet Gateway → Application Load Balancer (Public Subnet)
3. ALB → EKS Pods (Private Subnet)

### Outbound Traffic (Application → Internet)
1. EKS Pods/Lambda (Private Subnet) → NAT Gateway (Public Subnet)
2. NAT Gateway → Internet Gateway
3. Internet Gateway → Internet

### AWS Service Access (Application → AWS Services)
1. EKS Pods/Lambda (Private Subnet) → VPC Endpoint
2. VPC Endpoint → AWS Service (S3, DynamoDB, KMS, etc.)
3. **No internet gateway traversal** (private connectivity)

## High Availability

- **Multi-AZ Deployment**: Resources distributed across 3 availability zones
- **NAT Gateway Redundancy**: One NAT Gateway per AZ (no single point of failure)
- **RDS Multi-AZ**: Primary in AZ-a, replica in AZ-b
- **EKS Node Groups**: Distributed across all 3 AZs

## Security Features

1. **Network Isolation**: Private subnets have no direct internet access
2. **VPC Endpoints**: Private connectivity to AWS services
3. **Security Groups**: Applied at resource level (defined in subsequent tasks)
4. **Network ACLs**: Applied at subnet level (defined in subsequent tasks)
5. **Encryption in Transit**: All VPC endpoints support TLS

## Cost Considerations

### Monthly Costs (Approximate)

#### Production (3 NAT Gateways)
- NAT Gateways: 3 × $32.40 = $97.20
- NAT Gateway Data Transfer: ~$0.045/GB
- Interface VPC Endpoints: 5 × $7.20 = $36.00
- **Total**: ~$133.20 + data transfer

#### Development/Staging (1 NAT Gateway)
- NAT Gateway: 1 × $32.40 = $32.40
- NAT Gateway Data Transfer: ~$0.045/GB
- Interface VPC Endpoints: 5 × $7.20 = $36.00
- **Total**: ~$68.40 + data transfer

**Note**: Gateway endpoints (S3, DynamoDB) have no additional cost.

## Compliance Alignment

### DPDP Act (Digital Personal Data Protection Act)
- ✓ Network isolation for sensitive data
- ✓ Encryption in transit via VPC endpoints
- ✓ Private connectivity to storage services

### HIPAA-Ready Architecture
- ✓ Network segmentation (public/private subnets)
- ✓ Private connectivity to data services
- ✓ Multi-AZ for high availability
- ✓ VPC Flow Logs capability (to be enabled)

### ABDM (Ayushman Bharat Digital Mission)
- ✓ Secure network architecture
- ✓ High availability for healthcare services
- ✓ Compliance with healthcare data security standards

## Next Steps

1. **Task 1.2**: Configure security groups and network ACLs
2. **Task 1.3**: Set up AWS KMS for encryption
3. **Task 1.4**: Configure S3 buckets with encryption
4. **Task 2.1**: Provision RDS PostgreSQL in private subnets
5. **Task 6.1**: Provision EKS cluster in private subnets

## References

- [AWS VPC Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-best-practices.html)
- [AWS Multi-AZ Architecture](https://docs.aws.amazon.com/whitepapers/latest/real-time-communication-on-aws/high-availability-and-scalability-on-aws.html)
- [VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
