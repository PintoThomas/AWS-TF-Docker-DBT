## 🎯 Key Architectural Highlights

* **100% Infrastructure-as-Code**: Modular Terraform codebase managing S3 Buckets, Glue Data Catalog, ECR Repositories, IAM Least-Privilege Roles, and ECS Fargate compute.
* **Medallion Data Architecture**: Multi-layer data processing pipeline (Bronze Raw ➔ Silver Staging ➔ Gold Marts) leveraging **Apache Iceberg / Parquet** formats via AWS Athena.
* **Serverless Execution Engine**: Ephemeral job runs on **AWS ECS Fargate**—zero persistent servers, scaling down to **$0.00** when idle.
* **Automated CI/CD Pipeline**: GitHub Actions workflow automatically testing, building, tagging (`git sha`), and pushing container images to AWS ECR on every push to `main`.
* **Zero-Trust & Cloud Security**: Complete decoupling of access keys using IAM Task Execution Roles for runtime AWS service access.

---

## 🏗️ End-to-End System Architecture

```text
[ Raw Data Ingestion (CSV) ]
             │
             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. AWS INFRASTRUCTURE (Provisioned via Terraform)                       │
│    • S3 Raw Storage Bucket    : tf-docker-dbt-raw-data                  │
│    • S3 Analytical Marts      : tf-docker-dbt-marts-data                │
│    • Container Registry       : AWS ECR (tf-docker-dbt-dbt)             │
│    • Data Catalog             : AWS Glue Database (analytics_dev)       │
└─────────────────────────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2. DATA TRANSFORMATION & MODELING (dbt Core + AWS Athena)                │
│    • BRONZE  : External Table in AWS Glue Catalog (raw_customers)       │
│    • SILVER  : Cleaned Virtual Staging View (stg_customers.sql)         │
│    • GOLD    : Dimensional Analytics Mart (dim_customers.sql)           │
└─────────────────────────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 3. ORCHESTRATION & CONTAINERIZATION (Docker, ECR & ECS Fargate)         │
│    • GitHub Actions triggers image build on push to main                │
│    • Automated push to AWS ECR with immutable Git SHA tags              │
│    • Ephemeral ECS Fargate Task execution with CloudWatch logging       │
└─────────────────────────────────────────────────────────────────────────┘
📂 Repository Structure
Plaintext
AWS-TF-Docker-DBT/
├── .github/
│   └── workflows/
│       └── deploy-ecr.yml       # Automated GitHub Actions CI/CD workflow
├── infra/                       # Infrastructure-as-Code (Terraform)
│   ├── main.tf                  # AWS Provider, S3 Buckets, Glue Catalog & ECR
│   ├── ecs.tf                   # ECS Cluster, Task Definition & IAM Roles
│   ├── variables.tf             # Input variables & region definitions
│   └── outputs.tf               # Exported resource identifiers & URIs
├── deploy/                      # Analytical Transformation Codebase
│   ├── models/
│   │   ├── staging/             # Silver layer cleaning & standardization
│   │   └── marts/               # Gold layer dimensional modeling (Iceberg)
│   ├── Dockerfile               # Production image (python:3.11-slim + dbt-athena)
│   ├── dbt_project.yml          # dbt project configurations
│   └── profiles.yml             # Athena execution profiles
├── .gitignore                   # Excludes terraform providers, logs & binaries
└── README.md                    # Project documentation
🛠️ Quick Start Guide
1. Provision AWS Infrastructure
Bash
cd infra
terraform init
terraform plan
terraform apply -auto-approve
2. Local Container Testing
Bash
cd ../deploy

# Build local Docker image
docker build -t tf-docker-dbt .

# Run dbt transformations locally against AWS Athena
docker run --rm \
  -v "$HOME/.aws:/root/.aws:ro" \
  -e AWS_PROFILE=default \
  tf-docker-dbt run
3. Deploy Ephemeral Task on AWS ECS Fargate
Bash
# Retrieve default VPC Subnet ID
SUBNET_ID=$(aws ec2 describe-subnets --region eu-west-3 --query "Subnets[0].SubnetId" --output text)

# Trigger on-demand ECS Fargate container run
aws ecs run-task \
  --cluster dbt-execution-cluster \
  --task-definition dbt-run-task \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],assignPublicIp=ENABLED}" \
  --region eu-west-3