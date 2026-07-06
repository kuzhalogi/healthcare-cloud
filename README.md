# MedShare — Cloud-Based Healthcare Management System

A serverless hospital data sharing platform on AWS. Doctors and patients sign in, manage patient profiles, book appointments, and attach medical records. Every request is authenticated, encrypted at rest, and logged for audit.

Built as a deployable, tear-down-in-one-command demo. Running a demo and destroying the stack afterward keeps the cost near zero.

![Architecture](docs/architecture.svg)

## What this demonstrates

This project maps each pillar of a production healthcare architecture to a low-cost serverless service:

| Pillar | Service used | Why |
|---|---|---|
| Microservices | AWS Lambda | Three independent functions: patients, appointments, records |
| API layer | API Gateway (HTTP API) | Routes requests, validates Cognito tokens |
| Authentication | Amazon Cognito | Doctor and patient groups for role-based access |
| Structured data | DynamoDB | Pay-per-request, no idle cost |
| Document storage | Amazon S3 | Encrypted bucket, presigned upload URLs |
| Encryption | AWS KMS | Encryption at rest on DynamoDB and S3 |
| Access control | IAM | Least-privilege role scoped per function |
| Monitoring | CloudWatch | Central logs and a health dashboard |
| CDN + hosting | CloudFront + S3 | Static React frontend |

## Design decisions

I deliberately chose serverless over the EC2, Docker, and Kubernetes stack in the original proposal. Serverless removes idle cost and operational overhead, which matters for a demo that runs briefly and then shuts down. DynamoDB replaces RDS for the same reason: it charges per request instead of per hour.

I scoped SageMaker analytics, Kinesis telemedicine streaming, and multi-region failover as future work. They add cost and complexity without changing the core proof: authenticated, encrypted, role-based data sharing between healthcare users.

## Tech stack

Backend: Node.js 20 on AWS Lambda, AWS SDK v3
Frontend: React 18, Vite, amazon-cognito-identity-js
Infrastructure: Terraform
Cloud: AWS (Lambda, API Gateway, DynamoDB, S3, Cognito, KMS, IAM, CloudWatch, CloudFront)

## Prerequisites

- An AWS account with the AWS CLI configured (`aws configure`)
- Terraform 1.5 or later
- Node.js 20 or later
- A billing alarm set in AWS Budgets (see "Cost safety" below)

## Deploy

```bash
./deploy.sh
```

This installs the records function dependencies, runs Terraform, and prints the outputs you need for the frontend.

### Configure the frontend

Copy the Terraform outputs into `frontend/src/config.js`:

```bash
cd terraform && terraform output
```

Paste `api_url`, `cognito_user_pool_id`, and `cognito_client_id` into the config file.

### Create a demo user

```bash
./create-user.sh doctor@demo.com DemoPass123 doctors
```

### Run the frontend

```bash
cd frontend
npm install
npm run dev
```

Open the local URL, sign in with the demo user, and add patients, appointments, and records.

## Destroy

```bash
./destroy.sh
```

This deletes every resource. Your bill for the project returns to zero.

## Cost safety

Before deploying, set two billing alarms in AWS Budgets, at $1 and $5. You get an email the moment spending starts.

At demo scale, every service here sits inside the AWS Free Tier. The main cost risk is leaving resources running, so destroy the stack when you finish. Because the whole stack is defined in Terraform, you redeploy in a few minutes whenever you want to demo again.

## Project structure

```
healthcare-cloud/
├── terraform/          Infrastructure as code
│   ├── main.tf         Provider and variables
│   ├── data.tf         DynamoDB tables, S3, KMS
│   ├── auth.tf         Cognito user pool and groups
│   ├── iam.tf          Least-privilege Lambda role
│   ├── lambda.tf       Function definitions and packaging
│   ├── api.tf          API Gateway routes and authorizer
│   └── outputs.tf      CloudWatch dashboard and outputs
├── lambda/
│   ├── patient/        Patient management service
│   ├── appointment/    Appointment scheduling service
│   └── records/        Medical records service
├── frontend/           React app
├── deploy.sh
├── destroy.sh
└── create-user.sh
```

## Security notes

- All data at rest is encrypted with a customer-managed KMS key
- All data in transit uses TLS through API Gateway and CloudFront
- API routes require a valid Cognito JWT
- The Lambda IAM role can touch only this project's tables, bucket, and key
- S3 public access is fully blocked; documents upload through short-lived presigned URLs

This is a demo, not a HIPAA-certified production system. HIPAA compliance requires a signed AWS Business Associate Addendum, audit controls, and organizational safeguards beyond application code.
