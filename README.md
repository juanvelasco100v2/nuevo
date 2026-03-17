# BTG Pactual - Funds Management Platform (Infrastructure)

AWS infrastructure for the BTG Pactual funds management API. Deploys via CloudFormation and manages the full lifecycle through GitHub Actions.

## Architecture:

```
Internet
   │
   ▼
Route53 (juanvelasco100.click)
   │
   ▼
ALB (HTTPS, public subnets)
   │
   ▼
ECS Fargate (private subnets)
   │
   ├── DynamoDB (via VPC Endpoint)
   ├── SES (email notifications)
   ├── SNS (SMS notifications)
   └── Secrets Manager (JWT key)
```

## AWS Resources Created

| Resource | Purpose |
|---|---|
| VPC + Subnets | Network isolation (2 public + 2 private subnets, 2 AZs) |
| NAT Gateway | Outbound internet for private subnets |
| ALB | Load balancer with HTTPS (ACM certificate) |
| ECS Fargate | Container runtime for Spring Boot API |
| ECR | Docker image registry |
| DynamoDB (5 tables) | Users, Funds, Transactions, Roles, Subscriptions |
| SES | Email notifications (DKIM verified) |
| SNS | SMS notifications |
| Secrets Manager | JWT signing key (auto-generated) |
| Route53 Record | DNS A record pointing to ALB |
| CloudWatch Logs | Container logs (30 day retention) |
| VPC Endpoints | DynamoDB + S3 Gateway endpoints (free, reduces NAT traffic) |

## Prerequisites

- AWS CLI configured with credentials that have admin permissions
- GitHub account with a repository for this project
- Domain `juanvelasco100.click` with a Hosted Zone in Route53

## Quick Start

### 1. Get your Route53 Hosted Zone ID

```bash
aws route53 list-hosted-zones-by-name \
  --dns-name juanvelasco100.click \
  --query 'HostedZones[0].Id' \
  --output text
```

### 2. Configure GitHub Secrets

In your GitHub repository, go to **Settings > Secrets and variables > Actions** and add:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `HOSTED_ZONE_ID` | The Route53 zone ID from step 1 |

### 3. Deploy Infrastructure

The deploy triggers automatically when you merge changes to `main` or `dev` that affect `infrastructure/`. You can also trigger it manually from **Actions > Deploy Infrastructure > Run workflow**.

**Recommended flow:**

```bash
git checkout -b feature/my-infra-change
# ... make changes in infrastructure/
git add . && git commit -m "Update infrastructure"
git push origin feature/my-infra-change
# Create PR → merge to main or dev → deploy runs automatically
```

The first deployment takes ~10-15 minutes (ACM certificate DNS validation).

### 4. Seed Data

After deployment, seed the initial funds and roles:

```bash
# Seed the 5 BTG funds
bash scripts/seed-funds.sh btg-funds-funds us-east-1

# Seed default roles (ADMIN, CLIENT)
bash scripts/seed-roles.sh btg-funds-roles us-east-1
```

### 5. Deploy Application (separate project)

Once the Spring Boot application is ready:

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Build and push
docker build -t btg-funds-api .
docker tag btg-funds-api:latest <ecr-uri>:latest
docker push <ecr-uri>:latest

# Update ECS service (set DesiredCount to 1+)
aws ecs update-service \
  --cluster btg-funds-cluster \
  --service btg-funds-api-service \
  --desired-count 1 \
  --force-new-deployment
```

## Destroy Everything

Two options:

### Option A: Via merge (recommended)
```bash
git checkout -b destroy/cleanup
touch infrastructure/DESTROY
git add . && git commit -m "Trigger stack destruction"
git push origin destroy/cleanup
# Create PR → merge to main or dev → stack is destroyed
```

### Option B: Manual trigger
Go to **Actions > Destroy Infrastructure > Run workflow**, type `DELETE` in the confirmation field and run.

Both will:
1. Clean all images from ECR
2. Delete the entire CloudFormation stack
3. Remove all DynamoDB tables and data

**Warning:** This is irreversible. All data will be lost.

## Manual Deploy/Destroy (without GitHub Actions)

```bash
# Deploy
aws cloudformation deploy \
  --template-file infrastructure/cloudformation.yaml \
  --stack-name btg-funds-platform \
  --parameter-overrides \
    EnvironmentName=btg-funds \
    HostedZoneId=YOUR_ZONE_ID \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Destroy
aws ecr batch-delete-image \
  --repository-name btg-funds-api \
  --image-ids "$(aws ecr list-images --repository-name btg-funds-api --query 'imageIds[*]' --output json)" \
  --region us-east-1 2>/dev/null || true

aws cloudformation delete-stack \
  --stack-name btg-funds-platform \
  --region us-east-1
```

## DynamoDB Data Model

### Users
| Attribute | Type | Key |
|---|---|---|
| userId | String | PK |
| email | String | GSI (email-index) |
| name | String | |
| password | String | (bcrypt hash) |
| balance | Number | (starts at 500000) |
| notificationPreference | String | EMAIL or SMS |
| phone | String | |
| roleIds | StringSet | |

### Funds
| Attribute | Type | Key |
|---|---|---|
| fundId | String | PK |
| name | String | |
| minimumAmount | Number | |
| category | String | FPV or FIC |

### Transactions
| Attribute | Type | Key |
|---|---|---|
| transactionId | String | PK |
| userId | String | GSI PK |
| createdAt | String | GSI SK (ISO 8601) |
| fundId | String | |
| fundName | String | |
| type | String | SUBSCRIBE or CANCEL |
| amount | Number | |

### Roles (Dynamic)
| Attribute | Type | Key |
|---|---|---|
| roleId | String | PK |
| roleName | String | |
| description | String | |
| permissions | List | [{endpoint, methods}] |
| createdAt | String | |

### Subscriptions
| Attribute | Type | Key |
|---|---|---|
| userId | String | PK |
| fundId | String | SK |
| amount | Number | |
| subscribedAt | String | |

## Environment Variables (ECS Task)

| Variable | Source | Description |
|---|---|---|
| `SERVER_PORT` | Parameter | Spring Boot port (8080) |
| `AWS_REGION` | Stack region | AWS region |
| `DYNAMODB_TABLE_USERS` | Table name | Users table |
| `DYNAMODB_TABLE_FUNDS` | Table name | Funds table |
| `DYNAMODB_TABLE_TRANSACTIONS` | Table name | Transactions table |
| `DYNAMODB_TABLE_ROLES` | Table name | Roles table |
| `DYNAMODB_TABLE_SUBSCRIPTIONS` | Table name | Subscriptions table |
| `SNS_TOPIC_ARN` | SNS ARN | Notification topic |
| `SES_SENDER_EMAIL` | Derived | noreply@juanvelasco100.click |
| `JWT_SECRET` | Secrets Manager | Auto-generated 64 char key |

## Estimated Monthly Cost

| Resource | Cost |
|---|---|
| NAT Gateway | ~$32 |
| ALB | ~$16 |
| ECS Fargate (256 CPU, 512 MB) | ~$9 |
| DynamoDB (On-Demand) | ~$1-5 |
| Route53 Hosted Zone | $0.50 |
| Secrets Manager | $0.40 |
| CloudWatch Logs | ~$1 |
| SES/SNS | Pay per message |
| **Total (idle)** | **~$60/month** |

## Notes

- SES starts in **sandbox mode**. To send emails to unverified addresses, [request production access](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html).
- The ACM certificate is auto-validated via Route53 DNS. First deployment may take 10-15 minutes.
- DynamoDB tables use `DeletionPolicy: Delete` for easy cleanup.
- VPC Endpoints for DynamoDB and S3 are Gateway type (free) and reduce NAT Gateway data transfer costs.
