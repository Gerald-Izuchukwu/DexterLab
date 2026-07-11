# Dexter CyberLab — wallet backend infrastructure exercise

This repo covers the three parts of the technical challenge:

- **`ARCHITECTURE.md`** — architecture write-up: design decisions, security posture, cost awareness, what I'd add for production, and what I'd improve with more time. The diagram referenced there is included as `architecture-diagram.png`.
- **`terraform/`** — Infrastructure as Code for a representative slice of the architecture: VPC (public/private/data subnets across 2 AZs), an ECS Fargate service behind an ALB, and a Multi-AZ RDS PostgreSQL instance, with Secrets Manager for credentials and least-privilege IAM throughout.
- **`app/`** + **`docker-compose.yml`** + **`.github/workflows/ci.yml`** — a minimal Node/Express hello-world API, its Dockerfile, a compose file to run it locally, and a GitHub Actions pipeline that runs unit tests, builds the image, smoke-tests the health endpoint, and validates the Terraform.

## Running it locally

```bash
docker compose up --build
curl http://localhost:8080/healthz
curl http://localhost:8080/
```

## Validating the Terraform

```bash
cd terraform
terraform fmt -recursive
terraform init -backend=false
terraform validate
```

No `terraform apply` is required or expected — this is a write-only exercise, and no AWS credentials are needed to validate the code.

## Notes on scope

The Terraform models one representative ECS service rather than all three planned microservices (auth, transactions, KYC) to keep the reviewable slice focused, per the challenge's own guidance ("VPC plus an ECS service plus an RDS instance"). The pattern (task-scoped IAM role, own Secrets Manager entry, own log group) is meant to repeat per service. Secrets rotation is documented as a next step rather than hand-rolled, since production rotation should use AWS's published Secrets Manager rotation Lambda rather than custom code.
