AWS CI/CD Infrastructure – Cloud-Native Immutable Deployment Architecture

This project demonstrates a fully automated, production-style AWS infrastructure built using Terraform and GitHub Actions with OIDC authentication. It deploys a containerized FastAPI ECG ingestion service behind an Application Load Balancer with enforced HTTPS and Auto Scaling.

The system follows immutable infrastructure principles, secure IAM boundaries, and Git-driven deployments.

Architecture Overview

The architecture is divided into three clear layers:

1️) Infrastructure Layer (Terraform – Modular Design)

Infrastructure is provisioned using modular Terraform:

Modules:

ECR (container registry with immutable tags)

IAM (runtime EC2 role + instance profile)

ACM (SSL certificate with DNS validation)

ALB (HTTPS ingress + target group)

Compute (Launch Template + Auto Scaling Group)

Key infrastructure characteristics:

Remote S3 backend with versioning enabled

Image tag immutability enforced in ECR

Launch Templates with IMDSv2 enforced

Auto Scaling Group (min 2 instances, multi-AZ)

Rolling instance refresh on image updates

ALB with HTTP → HTTPS redirect

Route53 alias record integration

Separate security groups for ALB and EC2

2) CI/CD Layer (GitHub Actions + OIDC)

Deployment is fully Git-driven.

Pipeline flow:

Developer pushes to main branch

GitHub Actions authenticates to AWS using OIDC

Terraform initializes and applies infrastructure

Docker image is built

Image is tagged using Git commit SHA

Image is pushed to Amazon ECR

Auto Scaling Group performs rolling instance refresh

Security characteristics:

No static AWS credentials stored in GitHub

OIDC-based temporary role assumption

Least-privilege runtime IAM

Deploy role isolated from runtime role

Each deployment produces a deterministic and traceable release via commit SHA tagging.

3)  Runtime Layer (Containerized Service)

Each EC2 instance:

Boots using user-data provisioning

Installs Docker

Logs into ECR via IAM role

Pulls image using commit SHA

Runs container with restart policy

Enables AWS SSM for remote management

Does NOT allow SSH access

Inside container:

FastAPI service

nginx reverse proxy

Health endpoint exposed for ALB checks

Traffic Flow

Client → HTTPS → ALB → HTTP → EC2 → Docker Container → FastAPI Service

Detailed flow:

Client establishes TLS connection with ALB

HTTPS terminates at ALB

ALB forwards HTTP traffic to target group

EC2 instance receives traffic

nginx routes to FastAPI service

Service validates and stores ECG data

EC2 instances are never directly exposed to the internet.

Service Functionality
Endpoint

POST /ecg

Content-Type: multipart/form-data

Fields:

ecg_file (required)

MRN (required)

patient_name (optional)

DOB (optional)

timestamp (required)

Response

{
"status": "stored",
"record_id": "abc123"
}

What This Service Does

Accepts ECG image and metadata

Validates input

Stores data

Returns unique record identifier

What It Does Not Do

No frontend UI

No authentication screen

No user management system

Focus is on infrastructure automation and backend service deployment.

Security & IAM Design

This architecture enforces strict boundaries:

GitHub OIDC authentication instead of long-lived credentials

Separate IAM roles for deployment and runtime

Runtime role limited to ECR pull + SSM access

No S3 backend access for EC2 instances

ALB and EC2 security groups isolated

EC2 instances not publicly accessible

IMDSv2 enforced

HTTPS-only ingress

ECR Lifecycle Management

Image tags are immutable

Scan-on-push enabled

Lifecycle policy retains only last 5 images

Prevents storage sprawl and reduces cost

Infrastructure Reversibility

Infrastructure can be fully destroyed using a manual GitHub workflow requiring explicit confirmation.

This ensures:

Cost control

Safe teardown

Git-managed lifecycle

Accidental deletion prevention

Key Design Principles

Immutable Infrastructure

Git-driven Deployments

Least-Privilege IAM

Modular Terraform

Rolling Updates instead of in-place changes

Remote State Management

Secure CI Authentication

Technologies Used

AWS (EC2, ECR, ALB, ASG, ACM, Route53, IAM, S3, VPC, SSM)

Terraform (modular architecture)

GitHub Actions (OIDC)

Docker

FastAPI

nginx

Amazon Linux

Why This Project Matters

This project demonstrates:

Production-style cloud architecture

Secure CI/CD design

Immutable deployment strategies

Infrastructure as Code best practices

AWS service integration maturity

Automation-first mindset

Cost-aware infrastructure management
