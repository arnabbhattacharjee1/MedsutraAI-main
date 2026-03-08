# Security Groups and Network ACLs Documentation

## Overview

This document describes the security groups and network ACLs configured for the AI Cancer Detection and Clinical Summarization platform. These security controls implement defense-in-depth by providing both instance-level (security groups) and subnet-level (network ACLs) protection.

## Security Architecture

### Defense-in-Depth Strategy

1. **Network ACLs**: Stateless subnet-level firewall rules
2. **Security Groups**: Stateful instance-level firewall rules
3. **IAM Roles**: Service-level access control
4. **Encryption**: Data protection at rest and in transit

## Security Groups

### 1. EKS Cluster Security Group

**Purpose**: Controls traffic to/from the EKS control plane

**Resource**: `aws_security_group.eks_cluster`

**Inbound Rules**:
- Port 443 (HTTPS) from VPC CIDR - API server access from worker nodes

**Outbound Rules**:
- All traffic to 0.0.0.0/0 - Control plane to worker nodes communication

**Use Case**: Protects the Kubernetes API server and allows secure communication with worker nodes

---

### 2. EKS Nodes Security Group

**Purpose**: Controls traffic to/from EKS worker nodes and enables inter-pod communication

**Resource**: `aws_security_group.eks_nodes`

**Inbound Rules**:
- All traffic from itself (self-referencing) - **Inter-pod communication**
- Ports 1025-65535 (TCP) from EKS cluster SG - Kubelet and pod communication
- Port 443 (HTTPS) from EKS cluster SG - API server communication
- All traffic from ALB SG - Load balancer to pods

**Outbound Rules**:
- All traffic to 0.0.0.0/0 - Internet access via NAT gateway

**Use Case**: Enables AI agent pods to communicate with each other, receive traffic from the load balancer, and access external services

**Key Feature**: Self-referencing rule allows all pods in the cluster to communicate freely, essential for:
- Agent orchestration
- Redis inter-agent messaging
- Service mesh communication

---

### 3. RDS Security Group

**Purpose**: Restricts database access to Lambda and EKS only

**Resource**: `aws_security_group.rds`

**Inbound Rules**:
- Port 5432 (PostgreSQL) from Lambda SG - Lambda database queries
- Port 5432 (PostgreSQL) from EKS nodes SG - Agent database access

**Outbound Rules**:
- None (database doesn't need outbound connections)

**Use Case**: Ensures patient data in PostgreSQL is only accessible by authorized application components

**Security Principle**: Least privilege - only specific services can access the database

---

### 4. Lambda Security Group

**Purpose**: Controls Lambda function network access

**Resource**: `aws_security_group.lambda`

**Inbound Rules**:
- None (Lambda functions don't receive inbound connections)

**Outbound Rules**:
- Port 5432 (TCP) to RDS SG - Database connections
- Port 443 (HTTPS) to 0.0.0.0/0 - AWS services and external APIs
- Port 80 (HTTP) to 0.0.0.0/0 - External APIs if needed

**Use Case**: Allows Lambda functions to access RDS, S3, DynamoDB, and other AWS services

**Services Accessed**:
- RDS PostgreSQL (patient records)
- S3 (medical documents via VPC endpoint)
- DynamoDB (session state via VPC endpoint)
- Amazon Textract (OCR)
- Amazon Bedrock (AI models)

---

### 5. Application Load Balancer Security Group

**Purpose**: Controls traffic to the ALB serving EKS ingress

**Resource**: `aws_security_group.alb`

**Inbound Rules**:
- Port 443 (HTTPS) from 0.0.0.0/0 - Secure web traffic
- Port 80 (HTTP) from 0.0.0.0/0 - Redirect to HTTPS

**Outbound Rules**:
- All TCP traffic to EKS nodes SG - Forward to backend pods

**Use Case**: Public-facing load balancer for the web application

**Security Note**: HTTP traffic should be redirected to HTTPS in ALB listener rules

---

### 6. Redis Security Group

**Purpose**: Restricts Redis access to EKS nodes only

**Resource**: `aws_security_group.redis`

**Inbound Rules**:
- Port 6379 (Redis) from EKS nodes SG - Agent orchestrator access

**Outbound Rules**:
- None (Redis doesn't need outbound connections)

**Use Case**: Secure inter-agent communication via Redis message queue

---

## Network ACLs

Network ACLs provide an additional layer of security at the subnet level. They are stateless, meaning both inbound and outbound rules must be explicitly defined.

### Public Subnet NACL

**Purpose**: Controls traffic for public subnets (NAT gateways, load balancers)

**Resource**: `aws_network_acl.public`

**Inbound Rules**:
- Rule 100: Port 80 (HTTP) from 0.0.0.0/0
- Rule 110: Port 443 (HTTPS) from 0.0.0.0/0
- Rule 120: Ports 1024-65535 (ephemeral) from 0.0.0.0/0 - Return traffic
- Rule 130: Port 22 (SSH) from VPC CIDR - Management access

**Outbound Rules**:
- Rule 100: Port 80 (HTTP) to 0.0.0.0/0
- Rule 110: Port 443 (HTTPS) to 0.0.0.0/0
- Rule 120: Ports 1024-65535 (ephemeral) to 0.0.0.0/0 - Return traffic
- Rule 200+: All traffic to private subnets - NAT gateway forwarding

**Applied To**: All public subnets across 3 availability zones

---

### Private Subnet NACL

**Purpose**: Controls traffic for private subnets (EKS, RDS, Lambda)

**Resource**: `aws_network_acl.private`

**Inbound Rules**:
- Rule 100: All traffic from VPC CIDR - Inter-subnet communication
- Rule 110: Ports 1024-65535 (ephemeral) from 0.0.0.0/0 - Return traffic from NAT
- Rule 120: Port 443 (HTTPS) from 0.0.0.0/0 - AWS service endpoints

**Outbound Rules**:
- Rule 100: All traffic to VPC CIDR - Inter-subnet communication
- Rule 110: Port 80 (HTTP) to 0.0.0.0/0 - Via NAT gateway
- Rule 120: Port 443 (HTTPS) to 0.0.0.0/0 - Via NAT gateway
- Rule 130: Ports 1024-65535 (ephemeral) to 0.0.0.0/0 - Return traffic
- Rule 140: Port 5432 (PostgreSQL) to VPC CIDR - RDS access
- Rule 150: Port 6379 (Redis) to VPC CIDR - Redis access

**Applied To**: All private subnets across 3 availability zones

---

## Traffic Flow Examples

### 1. User Accessing Web Application

```
Internet → ALB (SG: alb, NACL: public)
       → EKS Nodes (SG: eks_nodes, NACL: private)
       → Application Pods
```

### 2. Lambda Function Querying Database

```
Lambda (SG: lambda, NACL: private)
     → RDS PostgreSQL (SG: rds, NACL: private)
```

### 3. AI Agent Accessing External Service

```
EKS Pod (SG: eks_nodes, NACL: private)
      → NAT Gateway (NACL: public)
      → Internet Gateway
      → External API (e.g., Amazon Bedrock)
```

### 4. Inter-Pod Communication (Agent Orchestration)

```
Agent Pod A (SG: eks_nodes, NACL: private)
          → Agent Pod B (SG: eks_nodes, NACL: private)
          [Allowed by self-referencing security group rule]
```

### 5. Agent Using Redis for Messaging

```
Agent Pod (SG: eks_nodes, NACL: private)
        → Redis (SG: redis, NACL: private)
```

---

## Compliance and Security Standards

### HIPAA-Ready Architecture (Requirement 13)

- **Access Control**: Security groups implement least privilege access
- **Audit Logging**: VPC Flow Logs enabled (configured separately)
- **Encryption in Transit**: All traffic uses TLS/SSL (enforced at application layer)
- **Network Segmentation**: Public/private subnet separation with NACLs

### DPDP Act Compliance (Requirement 12)

- **Data Protection**: RDS security group restricts database access
- **Network Isolation**: Private subnets for sensitive data processing
- **Controlled Access**: Security groups enforce authorized access only

### AWS Security Best Practices (Requirement 26.3)

- **Defense in Depth**: Both security groups and NACLs
- **Least Privilege**: Minimal required access for each component
- **Stateful Filtering**: Security groups track connection state
- **Stateless Filtering**: NACLs provide additional subnet-level protection

---

## Testing and Validation

### Validation Script

Run the test script to validate configuration:

```bash
cd infrastructure/terraform
chmod +x test_security_groups.sh
./test_security_groups.sh
```

### Manual Validation Checklist

- [ ] EKS nodes can communicate with each other (inter-pod)
- [ ] Lambda can connect to RDS on port 5432
- [ ] EKS nodes can connect to RDS on port 5432
- [ ] RDS cannot be accessed from internet
- [ ] Lambda can access S3 via VPC endpoint
- [ ] ALB can forward traffic to EKS nodes
- [ ] EKS nodes can access internet via NAT gateway
- [ ] Redis is only accessible from EKS nodes

### Security Testing

After deployment, verify:

1. **Port Scanning**: Ensure only intended ports are open
2. **Connection Testing**: Verify services can only connect as designed
3. **Egress Testing**: Confirm outbound traffic flows through NAT gateway
4. **Isolation Testing**: Verify RDS and Redis are not publicly accessible

---

## Maintenance and Updates

### Adding New Services

When adding new services:

1. Create a dedicated security group
2. Apply least privilege principle
3. Document inbound/outbound rules
4. Update this documentation
5. Test connectivity

### Security Group Naming Convention

Format: `${project_name}-${environment}-${service}-sg`

Example: `ai-cancer-detection-production-rds-sg`

### Rule Numbering for NACLs

- 100-199: Standard traffic rules
- 200-299: Custom application rules
- 300-399: Reserved for future use

---

## Troubleshooting

### Common Issues

**Issue**: Lambda cannot connect to RDS
- Check Lambda security group has outbound rule to RDS SG
- Check RDS security group has inbound rule from Lambda SG
- Verify Lambda is in VPC private subnets

**Issue**: EKS pods cannot communicate
- Verify self-referencing rule in eks_nodes security group
- Check NACL allows traffic within VPC CIDR
- Confirm pods are in same VPC

**Issue**: ALB cannot reach EKS pods
- Check ALB security group has outbound rule to eks_nodes SG
- Check eks_nodes security group has inbound rule from ALB SG
- Verify target group health checks

**Issue**: Services cannot access internet
- Verify NAT gateway is running
- Check route tables point to NAT gateway
- Confirm NACL allows outbound traffic

---

## Outputs

The following outputs are available after applying the configuration:

```hcl
eks_cluster_security_group_id
eks_nodes_security_group_id
rds_security_group_id
lambda_security_group_id
alb_security_group_id
redis_security_group_id
public_network_acl_id
private_network_acl_id
```

Use these outputs in other Terraform modules:

```hcl
# Example: Reference RDS security group in RDS module
security_group_ids = [data.terraform_remote_state.network.outputs.rds_security_group_id]
```

---

## References

- [AWS Security Groups](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)
- [AWS Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
- [EKS Security Best Practices](https://docs.aws.amazon.com/eks/latest/userguide/security-best-practices.html)
- [HIPAA on AWS](https://aws.amazon.com/compliance/hipaa-compliance/)

---

## Task Completion

**Task**: 1.2 Configure security groups and network ACLs

**Requirements Addressed**: 26.3

**Files Created**:
- `security_groups.tf` - Security group definitions
- `network_acls.tf` - Network ACL definitions
- `test_security_groups.sh` - Validation script
- `SECURITY_GROUPS.md` - This documentation

**Status**: ✅ Complete
