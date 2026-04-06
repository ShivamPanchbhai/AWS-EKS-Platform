# AWS CI/CD Infrastructure – Cloud-Native Immutable Platform
> Production-grade AWS platform built using Terraform, GitHub Actions (OIDC), and Docker with fully automated immutable deployments.
---

![AWS](https://img.shields.io/badge/AWS-Cloud-orange?logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-IaC-purple?logo=terraform)
![Docker](https://img.shields.io/badge/Docker-Container-blue?logo=docker)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI/CD-black?logo=githubactions)
![FastAPI](https://img.shields.io/badge/FastAPI-Backend-green?logo=fastapi)
![Nginx](https://img.shields.io/badge/Nginx-Reverse_Proxy-darkgreen?logo=nginx)
![Architecture](https://img.shields.io/badge/Architecture-Platform_Engineering-blue)
![Prometheus](https://img.shields.io/badge/Prometheus-Monitoring-orange?logo=prometheus)
![Grafana](https://img.shields.io/badge/Grafana-Dashboards-orange?logo=grafana)
![Alertmanager](https://img.shields.io/badge/Alertmanager-Alerting-red)

<br/>

![App Deploy](https://github.com/ShivamPanchbhai/AWS-CI-CD/actions/workflows/app_deploy.yml/badge.svg)
![Infra Deploy](https://github.com/ShivamPanchbhai/AWS-CI-CD/actions/workflows/infra.yml/badge.svg)
![Destroy](https://github.com/ShivamPanchbhai/AWS-CI-CD/actions/workflows/destroy.yml/badge.svg)

This project demonstrates a **production-style AWS platform** built using Terraform and GitHub Actions with OIDC authentication.

It implements a **fully automated, immutable deployment pipeline** where infrastructure, application, and runtime are all controlled through Git.



---

## Key Highlights

```text
• End-to-end CI/CD-driven infrastructure provisioning
• Immutable deployments using commit SHA image tagging
• OIDC-based authentication (no static AWS credentials)
• Multi-AZ high availability with Auto Scaling
• Fully containerized runtime with automated bootstrapping
• Safe destroy workflow for cost control
* Dynamic image tag resolution via SSM Parameter Store at instance boot
* Full observability stack with end-to-end validated alert pipeline
* EC2 service discovery for Prometheus scraping
```

---

## Architecture 

![Architecture Diagram](./architecture-diagram.png)


How It Works (End-to-End Flow)
1. Developer pushes code to GitHub

2. App Pipeline triggers:
   → Builds Docker image
   → Tags with commit SHA
   → Pushes image to ECR
   → Writes image tag to SSM Parameter Store

4. Infra Pipeline triggers:
   → Terraform apply

5. Auto Scaling Group:
   → Performs rolling instance refresh
   → New EC2 instances launch

6. EC2 bootstraps automatically:
   → Fetches latest image tag from SSM Parameter Store
   → Pulls image from ECR
   → Starts container

8. Traffic flow:
   Client → Route53 → ALB (HTTPS) → EC2 → Docker → FastAPI
---

## Architecture Layers

### 1. Bootstrap Layer

Establishes the **foundation and trust boundary**:

* GitHub OIDC provider
* IAM deploy role
* S3 backend (Terraform state)

Key outcome:
→ Enables **secure CI/CD without static credentials**

---

### 2. Infrastructure Layer (Terraform)

Modular infrastructure provisioning:

```text
Modules:
- ECR        → container registry
- IAM        → roles & instance profiles
- ACM        → TLS certificate provisioning
- ALB        → HTTPS ingress + target group
- Compute    → Launch Template + ASG + target tracking scaling policy
- Monitoring → Prometheus, Grafana, Alertmanager, CloudWatch Exporter
```

Key features:

* Multi-AZ Auto Scaling (HA)
* IMDSv2 enforced
* HTTPS enforced (ALB)
* Route53 integration
* Rolling instance refresh

---

### 3. CI/CD Layer (GitHub Actions)

Two independent pipelines:

#### App Pipeline

```text
Trigger: app/**

Flow:
• Build Docker image
• Tag with commit SHA
• Push to ECR
```

#### Infra Pipeline

```text
Trigger:
• terraform/**
• workflow_run (post app deploy)

Flow:
• Terraform apply
• Update Launch Template
• ASG rolling refresh
```

Key design:
→ **Decoupled pipelines + immutable deployments**

---

### 4. Runtime Layer

EC2 bootstraps automatically using user-data:

```text
• Install Docker
• Authenticate to ECR (IAM role)
• Pull image (commit SHA)
• Start container
• Enable SSM (no SSH)
```

Inside container:

```text
nginx → FastAPI (/health)
```

---
### 5. Observability Layer

Monitoring stack running on dedicated EC2:

```text
- Prometheus - metrics collection with EC2 service discovery
- Grafana - dashboards
- Alertmanager - email alerting
- CloudWatch Exporter - ASG capacity metrics
- Node Exporter - host-level metrics on all app instances

Alert pipeline validated end-to-end:
→ Stress test → ASG scales to max → ASGAtMaxCapacity fires
→ pending → firing → email notification → resolved

```

### 6. Operational Layer

Safe infrastructure lifecycle control:

```text
• Dedicated destroy workflow
• Manual trigger (workflow_dispatch)
• Explicit confirmation required
```

Purpose:
→ Prevent accidental deletion + control AWS costs

---

## Deployment Flow

```text
Code Push → GitHub Actions → Build Image → Push to ECR
→ Terraform Apply → Launch Template Update
→ ASG Instance Refresh → New Instances Pull Image
```

---

## Security Design

```text
• OIDC authentication (no AWS keys)
• Least-privilege IAM roles
• Separate deploy and runtime roles
• Private EC2 instances (no public exposure)
• HTTPS enforced via ALB
* IMDSv2 enforced on all EC2 instances
* SSM-based instance access (no SSH)
```

---

## Repository Structure

```text
.
.
├── .github/
│   └── workflows/
│       ├── app_deploy.yml       # Build, push to ECR, write tag to SSM
│       ├── infra.yml            # Terraform apply, ASG rolling refresh
│       └── destroy.yml         # Safe infrastructure teardown
├── bootstrap/
│   └── main.tf                  # OIDC provider, IAM deploy role, S3 backend
├── app/
│   ├── main.py                  # FastAPI application
│   ├── Dockerfile
│   ├── nginx.conf               # Reverse proxy config
│   └── requirements.txt
└── terraform/
    ├── main.tf
    ├── outputs.tf
    ├── variables.tf
    └── modules/
        ├── acm/                 # TLS certificate provisioning
        ├── alb/                 # HTTPS ingress + target group
        ├── compute/             # Launch Template + ASG + scaling policy
        │   ├── app_LT.tf
        │   ├── asg.tf
        │   └── variables.tf
        ├── ecr/                 # Container registry
        ├── iam/                 # Roles + instance profiles
        └── monitoring/          # Prometheus, Grafana, Alertmanager, CloudWatch Exporter
```

---

## Engineering Principles

```text
• Immutable infrastructure
• Git-driven deployments
• Infrastructure as Code
• High availability (multi-AZ)
• Secure authentication (OIDC)
• Automated recovery (ASG)
```

---

## Tech Stack

```text
AWS (EC2, ASG, ALB, ECR, IAM, S3, Route53, ACM, SSM, CloudShell)
Prometheus, Grafana, Alertmanager, CloudWatch Exporter, Node Exporter, SSM Parameter Store
Terraform
GitHub Actions (OIDC)
Docker
FastAPI
nginx
```

