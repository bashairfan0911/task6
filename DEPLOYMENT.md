# Strapi Deployment Architecture

## Overview

This project uses a **fully automated CI/CD pipeline** to build, push, and deploy a Strapi application to AWS using Docker, ECR, and Terraform.

## Architecture Diagram

```
Local Git Repository
        ↓
    git push
        ↓
GitHub Repository (main branch)
        ↓
┌─────────────────────────────────────┐
│   CI Pipeline (GitHub Actions)      │
│   .github/workflows/ci.yml           │
├─────────────────────────────────────┤
│ 1. Checkout code                    │
│ 2. Configure AWS credentials        │
│ 3. Login to ECR                     │
│ 4. Create ECR repository            │
│ 5. Build Docker image               │
│ 6. Push to ECR                      │
│ 7. Trigger CD workflow              │
└─────────────────────────────────────┘
        ↓ (Auto-trigger)
┌─────────────────────────────────────┐
│   CD Pipeline (GitHub Actions)      │
│   .github/workflows/terraform.yml    │
├─────────────────────────────────────┤
│ 1. Checkout code                    │
│ 2. Configure AWS credentials        │
│ 3. Clean stale Terraform state      │
│ 4. Terraform init                   │
│ 5. Terraform plan                   │
│ 6. Terraform apply                  │
│ 7. Get outputs (IP, URLs)           │
│ 8. Verify SSH connectivity          │
└─────────────────────────────────────┘
        ↓
┌─────────────────────────────────────┐
│      AWS Infrastructure             │
├─────────────────────────────────────┤
│ • ECR (Elastic Container Registry)  │
│   - Repository: strapi-app          │
│   - Images: tagged with commit SHA  │
│                                     │
│ • EC2 Instance                      │
│   - AMI: Ubuntu 22.04               │
│   - Instance Type: t2.micro         │
│   - Runs Docker container           │
│   - Pulls image from ECR            │
│   - Public IP: dynamically assigned │
│                                     │
│ • RDS PostgreSQL Database           │
│   - Instance: strapi-db-2           │
│   - Engine: PostgreSQL              │
│   - Class: db.t3.micro              │
│   - Database: strapi_db             │
│                                     │
│ • Security Groups                   │
│   - EC2: Allows HTTP(1337), SSH(22)│
│   - RDS: Allows PostgreSQL(5432)   │
│     from EC2 security group         │
│                                     │
│ • VPC & Subnets                     │
│   - Uses default VPC                │
│   - Default subnets for RDS         │
└─────────────────────────────────────┘
        ↓
    Strapi Application Running
    http://<PUBLIC_IP>:1337
```

## Deployment Flow

### 1. Code Push (Manual)
```bash
git push origin main
```

### 2. CI Pipeline - Build & Push Docker Image (~3-5 minutes)

**File**: `.github/workflows/ci.yml`

**Triggers**: On `git push` to `main` branch

**Steps**:
1. Checkout code from repository
2. Configure AWS credentials from GitHub Secrets
3. Login to AWS ECR
4. Create ECR repository if it doesn't exist
5. Build Docker image:
   - Base: Node.js 20 (Bullseye)
   - Install dependencies
   - Build Strapi admin panel
   - Compile TypeScript
6. Tag image with:
   - `latest` tag
   - Commit SHA tag
7. Push both tags to ECR
8. Auto-trigger CD pipeline

**Output**:
- Docker image in ECR: `301782007642.dkr.ecr.ap-south-1.amazonaws.com/strapi-app:latest`

### 3. CD Pipeline - Deploy Infrastructure (~10-15 minutes)

**File**: `.github/workflows/terraform.yml`

**Triggers**: Automatically after successful CI pipeline

**Steps**:

#### a) State Management
- Clean stale IAM resources from previous runs
- Initialize Terraform backend

#### b) Infrastructure as Code
Run Terraform configuration (`terraform/`) to:
- Create/update ECR repository reference
- Create RDS PostgreSQL database
- Create EC2 instance with Docker
- Configure security groups
- Setup network connectivity

#### c) EC2 Instance Setup
When EC2 instance starts, `user_data` script:
1. Installs Docker and AWS CLI
2. Configures AWS credentials
3. Authenticates to ECR
4. Pulls Docker image
5. Waits 90 seconds for RDS to be ready
6. Starts Strapi container with environment variables:
   - `DATABASE_CLIENT=postgres`
   - `DATABASE_HOST=<RDS-endpoint>`
   - `DATABASE_PORT=5432`
   - `DATABASE_NAME=strapi_db`
   - `DATABASE_USERNAME=strapi`
   - `DATABASE_PASSWORD=strapi123`
   - `DATABASE_SSL=true`
   - `HOST=0.0.0.0`
   - `PORT=1337`

#### d) Output & Verification
- Extract outputs: Public IP, Strapi URL, ECR repository
- Verify SSH connectivity to EC2
- Display deployment summary

**Outputs**:
- Public IP: `13.204.66.133` (example)
- Strapi URL: `http://13.204.66.133:1337`
- ECR Repository: `301782007642.dkr.ecr.ap-south-1.amazonaws.com/strapi-app`

## AWS Resources Created

### 1. ECR Repository
- **Name**: `strapi-app`
- **Region**: ap-south-1
- **Images**: Built by CI pipeline
- **Tags**: `latest`, commit SHA

### 2. EC2 Instance
- **ID**: `i-0d0e5bec0963f8679` (current)
- **AMI**: Ubuntu 22.04 LTS
- **Type**: t2.micro (free tier)
- **Security Group**: `strapi-sg`
- **Ports**:
  - 22 (SSH)
  - 1337 (Strapi)
- **Public IP**: Dynamically assigned

### 3. RDS Database
- **Identifier**: `strapi-db-2`
- **Engine**: PostgreSQL
- **Class**: db.t3.micro (free tier)
- **Storage**: 20GB
- **Security Group**: `strapi-rds-sg`
- **Port**: 5432
- **Credentials**:
  - Username: `strapi`
  - Password: `strapi123`
  - Database: `strapi_db`

### 4. Security Groups
- **strapi-sg** (EC2):
  - Ingress: 1337 (0.0.0.0/0), 22 (SSH)
  - Egress: All traffic
  
- **strapi-rds-sg** (RDS):
  - Ingress: 5432 from strapi-sg
  - Egress: All traffic

### 5. DB Subnet Group
- **Name**: `strapi-db-subnet-group-2`
- **Subnets**: Default VPC subnets

## Configuration Files

### 1. Terraform Configuration

**Location**: `terraform/`

- **main.tf**: Resource definitions
- **variables.tf**: Input variables
- **outputs.tf**: Output values
- **terraform.tfvars**: Variable values

**Key Variables**:
- `aws_region`: ap-south-1
- `instance_type`: t2.micro
- `docker_image`: ECR image URI
- `aws_access_key_id`: From GitHub Secrets
- `aws_secret_access_key`: From GitHub Secrets

### 2. GitHub Actions Workflows

**Location**: `.github/workflows/`

- **ci.yml**: Build and push Docker image
- **terraform.yml**: Deploy infrastructure

### 3. Dockerfile

**Location**: Root directory

- Base image: node:20-bullseye
- Installs npm dependencies
- Builds Strapi
- Runs application on port 1337

## Accessing the Deployment

### 1. Strapi Admin Panel
```
URL: http://<PUBLIC_IP>:1337/admin
```

First login:
- Create admin user and password
- Access the CMS

### 2. SSH Access
```bash
ssh -i terraform/id_rsa ubuntu@<PUBLIC_IP>
```

Check Docker container:
```bash
docker ps
docker logs strapi
```

### 3. Database Access
From EC2:
```bash
psql -h <RDS_ENDPOINT> -U strapi -d strapi_db
```

## Monitoring & Troubleshooting

### View CI Pipeline
1. GitHub → Actions
2. Select "CI - Build and Push Docker Image to ECR"
3. Check recent runs and logs

### View CD Pipeline
1. GitHub → Actions
2. Select "CD - Deploy with Terraform"
3. Check recent runs and logs

### Check EC2 Instance
1. AWS Console → EC2 → Instances
2. Find instance named "strapi-ubuntu-ec2"
3. View logs:
   ```bash
   ssh -i terraform/id_rsa ubuntu@<IP>
   docker logs strapi -f
   ```

### Check RDS Database
1. AWS Console → RDS → Databases
2. Find instance "strapi-db-2"
3. Check status and metrics

### Common Issues

**Issue**: "Repository does not exist"
- **Solution**: CI workflow creates it automatically on first run

**Issue**: "EC2 instance not responding"
- **Solution**: Wait 2-3 minutes for startup, check security group rules

**Issue**: "Database connection failed"
- **Solution**: Check RDS security group allows EC2 traffic, check credentials

**Issue**: "Strapi container not starting"
- **Solution**: SSH to EC2, check logs: `docker logs strapi`

## Deployment Timeline

| Step | Duration | Action |
|------|----------|--------|
| Code Push | Instant | Push to GitHub |
| CI Build | 2-3 min | Docker build + push |
| CI→CD Trigger | <1 min | Auto-trigger |
| Terraform Init | <1 min | Initialize Terraform |
| RDS Creation | 4-5 min | Create PostgreSQL DB |
| EC2 Launch | 1-2 min | Launch Ubuntu instance |
| Container Startup | 2-3 min | Wait for RDS + start Strapi |
| **Total** | **~15-20 min** | Full deployment |

## Costs

**Free Tier Usage**:
- t2.micro EC2 instance: Free (first 12 months)
- db.t3.micro RDS: Free (first 12 months)
- ECR: ~$0.10/GB stored (minimal)

**Monthly Estimate**: $0.10-1.00 (during free tier)

## Security Notes

⚠️ **Important**:
1. Database password in Terraform - use AWS Secrets Manager in production
2. SSH key stored locally - keep private, don't commit
3. AWS credentials in GitHub Secrets - use IAM roles in production
4. EC2 instance allows SSH from 0.0.0.0/0 - restrict to your IP in production

## Next Steps

1. **Test Deployment**: Push a change and watch the workflow
2. **Access Strapi**: Navigate to Strapi URL and create admin user
3. **Create Content**: Add content types and collections
4. **Configure Database**: Set up PostgreSQL connections
5. **Scale**: Modify instance type for production workloads

## References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Strapi Documentation](https://docs.strapi.io)
- [GitHub Actions](https://docs.github.com/en/actions)
- [AWS ECR](https://docs.aws.amazon.com/ecr/)
- [AWS EC2](https://docs.aws.amazon.com/ec2/)
- [AWS RDS](https://docs.aws.amazon.com/rds/)
