# BTG Pactual - Funds Management Platform (Infrastructure)

AWS infrastructure for the BTG Pactual funds management API. Deploys via CloudFormation and manages the full lifecycle through GitHub Actions.

## Architecture

```
Internet
   |
   v
Route53 (juanvelasco100.click)
   |
   v
ALB (HTTPS, public subnets)
   |
   v
ECS Fargate (private subnets, auto scaling 1-2 tasks)
   |
   |-- DynamoDB (via VPC Endpoint)
   |-- SES (email notifications)
   |-- SNS (SMS notifications)
   +-- Secrets Manager (JWT key)
```

## AWS Resources Created

| Resource | Purpose |
|---|---|
| VPC + Subnets | Network isolation (2 public + 2 private subnets, 2 AZs) |
| NAT Gateway | Outbound internet for private subnets |
| ALB | Load balancer with HTTPS (ACM certificate) |
| ECS Fargate | Container runtime for Spring Boot API (512 CPU / 1024 MB) |
| Auto Scaling | CPU-based scaling (target 75%, min 1, max 2 tasks) |
| ECR | Docker image registry |
| DynamoDB (5 tables) | Users, Funds, Transactions, Roles, Subscriptions |
| SES | Email notifications (DKIM verified) |
| SNS | SMS notifications |
| Secrets Manager | JWT signing key (auto-generated) |
| Route53 Record | DNS A record pointing to ALB |
| CloudWatch Logs | Container logs (7 day retention) |
| VPC Endpoints | DynamoDB + S3 Gateway endpoints (free, reduces NAT traffic) |

## Prerequisites

- AWS CLI configured with credentials that have admin permissions
- GitHub account with a repository for this project
- Domain `juanvelasco100.click` with a Hosted Zone in Route53

## Quick Start

### 1. Configure GitHub Secrets

In your GitHub repository, go to **Settings > Secrets and variables > Actions** and add:

| Secret | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | Your AWS access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key |
| `HOSTED_ZONE_ID` | The Route53 zone ID |

### 2. Deploy Infrastructure

The deploy triggers automatically when you merge changes to `main` or `dev` that affect `infrastructure/`. You can also trigger it manually from **Actions > Deploy Infrastructure > Run workflow**.

### 3. Seed Data

After deployment, create the initial funds and roles:

```bash
bash scripts/seed-roles.sh dev-roles us-east-1
```

### 4. Deploy Application (separate project)

Once the Spring Boot application is ready:
https://github.com/juanvelasco100v2/btg-funds-api

The CI/CD pipeline in btg-funds-api automatically:
1. Builds the Docker image
2. Pushes it to ECR
3. Registers a new ECS task definition with the image
4. Updates the ECS service with `desired-count 1`

### Destroy + Recreate Flow

1. Destroy the stack (via GitHub Actions or CLI)
2. Create the stack again
3. Push any change to `dev` in btg-funds-api → CI/CD rebuilds and deploys everything automatically

No secrets need to be updated since the resource names (`dev-cluster`, `dev-api-service`, etc.) and ECR URI remain the same.

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
| `DYNAMODB_TABLE_USERS` | Table name | dev-users |
| `DYNAMODB_TABLE_FUNDS` | Table name | dev-funds |
| `DYNAMODB_TABLE_TRANSACTIONS` | Table name | dev-transactions |
| `DYNAMODB_TABLE_ROLES` | Table name | dev-roles |
| `DYNAMODB_TABLE_SUBSCRIPTIONS` | Table name | dev-subscriptions |
| `SNS_TOPIC_ARN` | SNS ARN | Notification topic |
| `SES_SENDER_EMAIL` | Derived | noreply@juanvelasco100.click |
| `JWT_SECRET` | Secrets Manager | Auto-generated 64 char key |

## Costs (estimated, 1 task 24/7)

| Resource | Monthly (USD) |
|---|---|
| NAT Gateway | ~$32 |
| ALB | ~$16 |
| ECS Fargate (512 CPU, 1024 MB) | ~$18 |
| DynamoDB On-Demand | ~$1-5 |
| Other (Route53, Secrets, Logs) | ~$2 |
| **Total** | **~$70/month** |
