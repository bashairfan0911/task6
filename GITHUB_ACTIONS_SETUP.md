# GitHub Actions Setup Guide

## Required GitHub Secrets

To enable the CI/CD and Terraform deployment workflows, configure the following secrets in your GitHub repository:

### Repository Secrets Configuration

Go to **Settings → Secrets and Variables → Actions** and add:

#### 1. Docker Hub Credentials
- **Name**: `DOCKER_USERNAME`
  - **Value**: Your Docker Hub username
  - **Example**: `shantanu2001`

- **Name**: `DOCKER_PASSWORD`
  - **Value**: Your Docker Hub access token (NOT your password)
  - **How to get**: 
    1. Go to [Docker Hub Account Settings](https://hub.docker.com/settings/security)
    2. Create a new access token
    3. Copy the token and use it here

#### 2. AWS Credentials
- **Name**: `AWS_ACCESS_KEY_ID`
  - **Value**: Your AWS access key
  - **How to get**:
    1. Go to [AWS IAM Console](https://console.aws.amazon.com/iam/home)
    2. Click on your user (bashairfan518@gmail.com)
    3. Go to "Security credentials" tab
    4. Click "Create access key" (or use existing one)
    5. Copy the Access Key ID

- **Name**: `AWS_SECRET_ACCESS_KEY`
  - **Value**: Your AWS secret access key
  - **Note**: Keep this secret and never commit it
  - **How to get**: Same location as AWS_ACCESS_KEY_ID

## Workflow Overview

### 1. CI Pipeline (`.github/workflows/ci.yml`)

**Trigger**: Automatically on `git push` to `main` branch

**What it does**:
- Builds Docker image of Strapi application
- Pushes image to Docker Hub
- Tags with: `main-<short-sha>`, `latest`, and semantic versions
- Outputs image digest for traceability

**Example output**:
```
Docker Hub: shantanu2001/strapi-app:latest
Docker Hub: shantanu2001/strapi-app:main-a1b2c3d
```

### 2. CD Pipeline (`.github/workflows/terraform.yml`)

**Trigger**: Manual via GitHub Actions UI (workflow_dispatch)

**What it does**:
1. Pulls latest code
2. Configures AWS credentials from secrets
3. Runs `terraform init`
4. Runs `terraform plan`
5. Runs `terraform apply`
6. Outputs EC2 public IP and Strapi URL
7. Verifies SSH connectivity
8. Provides deployment summary

## Usage Instructions

### Step 1: Add GitHub Secrets
1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret above

### Step 2: Push Code to Trigger CI
```bash
git add .
git commit -m "Set up GitHub Actions workflows"
git push origin main
```

This automatically triggers the CI pipeline, which:
- Builds your Strapi Docker image
- Pushes it to Docker Hub as `shantanu2001/strapi-app:latest`

### Step 3: Deploy with Terraform (Manual)
1. Go to GitHub → **Actions** tab
2. Select **"CD - Deploy with Terraform"** workflow
3. Click **"Run workflow"**
4. Select branch: `main`
5. Click green **"Run workflow"** button
6. Wait for completion (~5-10 minutes)

### Step 4: Access Your Deployment
Once Terraform completes, you'll see:
- **Public IP**: EC2 instance IP address
- **SSH Command**: `ssh -i terraform/id_rsa ubuntu@<PUBLIC_IP>`
- **Strapi URL**: `http://<PUBLIC_IP>:1337`

**Note**: The Docker container takes 2-3 minutes to start (includes 90-second RDS wait). Check logs:
```bash
ssh -i terraform/id_rsa ubuntu@<PUBLIC_IP>
docker logs strapi
```

## Workflow Status Checks

### View CI Pipeline Status
1. Go to **Actions** tab
2. Look for "CI - Build and Push Docker Image"
3. Check recent runs
4. Click on a run to see detailed logs

### View CD Pipeline Status
1. Go to **Actions** tab
2. Look for "CD - Deploy with Terraform"
3. Click on the latest run
4. View step-by-step execution and outputs

## Troubleshooting

### CI Pipeline Issues

**Error: "Login to Docker Hub failed"**
- Verify `DOCKER_USERNAME` is correct
- Ensure `DOCKER_PASSWORD` is a Docker Hub **access token**, not your password
- Check token hasn't expired

**Error: "Build failed"**
- Ensure `Dockerfile` exists in root directory
- Check build context in `.github/workflows/ci.yml`

### CD Pipeline Issues

**Error: "AWS credentials not valid"**
- Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are correct
- Check IAM user has EC2, RDS, and VPC permissions
- Test credentials locally: `aws sts get-caller-identity`

**Error: "Terraform state lock"**
- Workspace may be locked from previous failure
- Remove lock: `cd terraform && terraform force-unlock <LOCK_ID>`

**SSH Connection Timeout**
- Wait 2-3 minutes for user_data script to complete
- Check security group allows SSH (port 22) from your IP
- Verify EC2 instance is running in AWS Console

## Environment Variables

Both workflows use:
- **AWS_REGION**: `ap-south-1` (hardcoded in workflows)
- **TERRAFORM_DIR**: `terraform` (location of your Terraform files)

To change region, edit `.github/workflows/terraform.yml`:
```yaml
env:
  AWS_REGION: us-east-1  # Change this
```

## Security Best Practices

1. **Never commit secrets** to the repository
2. **Rotate access keys** every 90 days
3. **Use minimal IAM permissions** - don't use root account
4. **Monitor GitHub Actions logs** for sensitive data leaks
5. **Restrict workflow permissions** - workflows have specific GitHub permissions

## Next Steps

1. ✅ Add GitHub Secrets
2. ✅ Push code to main branch (triggers CI)
3. ✅ Manually trigger Terraform workflow (from Actions tab)
4. ✅ Access EC2 instance via SSH
5. ✅ Monitor Strapi container startup
6. ✅ Access Strapi at the provided URL

---

**Questions?** Check the GitHub Actions logs or AWS Console for detailed error messages.
