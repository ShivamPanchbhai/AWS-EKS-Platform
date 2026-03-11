# AWS CI/CD Infrastructure – Cloud-Native Immutable Deployment (Oracle Project)

This project reflects the architecture and automation patterns I implemented at Oracle while working as a Platform Engineer on the CAMM7 platform.

I designed and automated end-to-end AWS infrastructure using Terraform and GitHub Actions with OIDC authentication, deploying a containerized backend service behind an Application Load Balancer with enforced HTTPS and Auto Scaling.

The system follows immutable infrastructure principles, secure IAM trust boundaries, and fully Git-driven deployments.

---

# Architecture Overview

The platform is structured into **five architectural layers**:

1. Bootstrap Layer  
2. Infrastructure Layer  
3. CI/CD Layer  
4. Runtime Layer  
5. Operational Layer  

---

# Architecture Diagram
Client
│
▼
Route53 (DNS)
│
▼
Application Load Balancer (HTTPS)
│
▼
Target Group
│
▼
Auto Scaling Group (EC2)
│
▼
Docker Container
│
▼
FastAPI Application


---

# Repository Structure
.
├── bootstrap/
│ └── bootstrap.tf
│
├── terraform/
│ ├── modules/
│ │ ├── ecr/
│ │ ├── iam/
│ │ ├── acm/
│ │ ├── alb/
│ │ └── compute/
│ └── main.tf
├── app/
│ ├── Dockerfile
│ ├── main.py
│ └── requirements.txt
│
└── .github/
└── workflows/
├── infra.yml
├── app-deploy.yml
└── destroy.yml



---

# 1. Bootstrap Layer (Foundation)

This layer establishes the **trust boundary and Terraform backend** required before CI/CD pipelines can run.

Provisioned components:

- GitHub **OIDC provider**
- **Deploy IAM role** assumed by GitHub Actions
- **S3 backend bucket** for Terraform state storage

Security characteristics:

- No static AWS credentials required
- GitHub workflows authenticate using **OIDC temporary tokens**
- Terraform state stored remotely with **versioning enabled**
- Public access fully blocked on the backend bucket

This bootstrap stack is executed **once manually** (via CloudShell) and then all infrastructure changes are handled through CI/CD.

---

# 2. Infrastructure Layer (Terraform – Modular Design)

Infrastructure is provisioned using **modular Terraform architecture** with clear separation of concerns.

Modules implemented:

- **ECR** – immutable container registry with scan-on-push
- **IAM** – runtime EC2 role and instance profile
- **ACM** – TLS certificates with DNS validation
- **ALB** – HTTPS ingress with target groups
- **Compute** – Launch Template and Auto Scaling Group

Key architectural characteristics:

- Remote S3 backend with versioning enabled
- Launch Templates with **IMDSv2 enforced**
- Auto Scaling Group (**minimum 2 instances, multi-AZ**)
- Target tracking auto scaling policy
- Rolling instance refresh for immutable deployments
- HTTP → HTTPS redirect at ALB
- Route53 alias record integration
- Separate security groups for ALB and EC2

---

# 3. CI/CD Layer (GitHub Actions + OIDC)

Deployments are fully **Git-driven** using GitHub Actions workflows.

Two separate pipelines were designed:

### Infrastructure Pipeline

Triggered when files in **terraform/** change.

Responsibilities:

- Authenticate to AWS using **OIDC**
- Initialize Terraform backend
- Apply infrastructure changes

### Application Pipeline

Triggered when files in **app/** change.

Pipeline flow:

1. Code push to main branch
2. GitHub Actions authenticates to AWS via OIDC
3. Docker image is built
4. Image tagged using **Git commit SHA**
5. Image pushed to **Amazon ECR**
6. Terraform updates Launch Template image_tag
7. **Auto Scaling Group performs rolling instance refresh**

Security controls implemented:

- No static AWS credentials stored in GitHub
- OIDC-based temporary role assumption
- Separate deploy role and runtime role
- Least-privilege IAM enforcement

Each deployment produces a **deterministic and traceable release**.

---

# 4. Runtime Layer (Containerized Service)

Each EC2 instance bootstraps automatically using **user-data scripts**.

Instance initialization performs:

- Docker installation
- ECR authentication using IAM role
- Pull container image using commit SHA
- Start container with restart policy
- Enable AWS SSM for remote management
- Disable SSH access

Inside the container:

- FastAPI backend service
- nginx reverse proxy
- Health endpoints exposed for ALB checks

---

# 5. Operational Layer

This layer manages **infrastructure lifecycle operations**.

Implemented controls:

- Dedicated **destroy workflow**
- Manual trigger via GitHub `workflow_dispatch`
- Explicit confirmation required before executing `terraform destroy`

This enables safe **full-stack teardown** for cost control while preventing accidental deletion.

---

# Traffic Flow

Client → HTTPS → ALB → HTTP → EC2 → Docker Container → FastAPI Service

Detailed lifecycle:

- Client establishes TLS connection with ALB
- HTTPS terminates at ALB
- ALB forwards HTTP traffic to target group
- EC2 instance receives request
- nginx forwards request to FastAPI
- Service processes and stores ECG data

EC2 instances are **never directly exposed to the internet**.

---

# Key Engineering Principles Applied

- Immutable infrastructure
- Git-driven deployments
- Least-privilege IAM
- Modular Terraform architecture
- Rolling instance refresh
- Remote state management
- Secure CI authentication

---

# Technologies Used

AWS (EC2, ECR, ALB, ASG, ACM, Route53, IAM, S3, VPC, SSM)  
Terraform  
GitHub Actions (OIDC)  
Docker  
FastAPI  
nginx  
Amazon Linux
