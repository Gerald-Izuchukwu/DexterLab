# Architecture write-up — Dexter CyberLab wallet backend

## Overview

The backend is designed as a set of containerized microservices (auth, transactions, KYC) running on ECS Fargate inside a VPC with a strict public/private split. The guiding principle throughout is: nothing that touches money or identity documents should be reachable from the public internet, and no single compromised component should be able to reach data or secrets outside its own blast radius.

## VPC design

The VPC (`10.0.0.0/16`) spans two availability zones for high availability, with three subnet tiers repeated per AZ:

- **Public subnets** — hold only the Application Load Balancer and NAT gateways. No compute or data ever lives here.
- **Private compute subnets** — run the ECS Fargate tasks. These can reach the internet outbound (via NAT, for pulling images or calling third-party KYC/payment APIs) but are not reachable inbound except from the ALB's security group.
- **Private data subnets** — host RDS. Security groups only permit inbound traffic from the compute subnet's security group on the Postgres port. No route to the internet at all.

Route tables enforce this: public subnets route `0.0.0.0/0` to an internet gateway, private subnets route `0.0.0.0/0` to a NAT gateway, and data subnets have no default route beyond the VPC's local traffic. This means even a misconfigured security group rule on the database can't accidentally expose it to the internet — the network layer itself doesn't provide a path.

## Compute choice: ECS Fargate

I considered ECS Fargate, EKS, and EC2 + ASG. Fargate is the right fit here for three reasons specific to this workload:

1. **Task-level IAM isolation.** Each service (auth, transactions, KYC) gets its own task role with only the permissions it needs — the KYC service's role has no access to payment-related secrets or tables, and vice versa. This limits the blast radius of any single service being compromised, which matters a lot more in a fintech context than in a typical web app.
2. **No host to patch or harden.** There's no EC2 fleet or Kubernetes control plane to keep current, which removes a whole category of operational risk for a small team — and removes an attack surface (the underlying host) that would otherwise need its own monitoring and patching cadence.
3. **Operational simplicity that matches team size.** EKS's flexibility (service mesh, custom operators, multi-cloud portability) isn't needed yet, and its extra surface area — node groups, cluster upgrades, more moving parts to misconfigure — is overhead the project doesn't need to carry this early. If the platform grows into many teams and needs deep Kubernetes-ecosystem tooling, EKS becomes worth revisiting; today, that trade isn't worth it.

Scaling is handled with ECS service auto-scaling on request count and CPU, and the ALB does path-based routing (`/auth/*`, `/transactions/*`, `/kyc/*`) to the appropriate service.

## Database and backups

RDS PostgreSQL, Multi-AZ, in the private data subnet. Multi-AZ gives synchronous replication to a standby in a second AZ with automatic failover, so a single AZ outage doesn't take the ledger down.

Backup strategy:
- Automated daily snapshots with point-in-time recovery enabled (5-minute recovery granularity), retained per the compliance window the product needs (I'd start at 14–35 days and confirm against whatever regulatory retention Dexter's KYC/AML obligations require).
- Storage encrypted at rest with a customer-managed KMS key, not the default AWS-managed key — this makes key rotation and access auditing explicit and controllable.
- A periodic cross-region copy of snapshots for disaster recovery, since a region-level event is unlikely but not something a wallet product can shrug off.

## Load balancing, scaling, and high availability

The ALB terminates TLS (ACM-issued certificate) and does path-based routing across AZs. Each ECS service runs a minimum of 2 tasks spread across AZs so there's no single point of failure at the compute layer, with auto-scaling policies to handle transaction bursts (e.g. payday, promotional periods). Health checks at the ALB target group level pull unhealthy tasks out of rotation automatically.

## Secrets management and data protection

- **Secrets Manager** holds DB credentials and third-party API keys (KYC vendor, payment processor). Credentials are injected into tasks at runtime via the ECS task execution role — they never live in environment variables baked into an image or in the repo.
- **Automatic rotation** is configured for DB credentials, so a leaked credential has a short shelf life.
- **KYC documents** land in a private S3 bucket, encrypted with SSE-KMS, accessed only through a VPC endpoint — so document uploads and retrievals never traverse the public internet, even internally. The bucket policy denies any non-TLS request outright.
- **IAM** follows least privilege throughout: task roles are scoped per service, there are no long-lived static AWS credentials anywhere in the pipeline (CI assumes a role via OIDC, discussed in the CI section), and administrative access to production is separated from the CI/CD deploy role.

## Cost awareness

Fargate's pay-per-task model avoids paying for idle EC2 capacity, which matters for an early-stage product with unpredictable traffic. NAT gateways are the main fixed cost to watch (they're billed per-hour plus per-GB processed) — for a low-traffic MVP, a single NAT gateway shared across AZs is a reasonable cost/availability trade-off, upgraded to one per AZ once traffic or compliance requirements justify it. RDS Multi-AZ roughly doubles the database cost versus single-AZ, which is a deliberate trade for a payments ledger — this is not somewhere to cut corners to save money. Observability (ELK, Prometheus/Grafana) is deliberately left out of this MVP slice to control cost; CloudWatch's native metrics and logs cover the basics until traffic justifies the extra spend.

## What I'd add to make this genuinely production-ready

- A WAF in front of the ALB (rate limiting, managed rule sets for common exploits — this matters more for a public-facing fintech API than most apps).
- GuardDuty and Security Hub for continuous threat detection and compliance posture checks.
- A proper observability stack (structured logging to a central store, dashboards, alerting on error rates and latency) — CloudWatch alone gets thin once you have three services and real traffic.
- A documented incident response runbook and a game-day/chaos testing practice, given the cost of a wallet outage or data incident.
- Formal threat modeling and a PCI-DSS gap assessment if card data enters the picture at all, even indirectly.

## What I'd improve with more time

- Terraform modules per subsystem (networking, compute, data) rather than one flat configuration, so each piece can be tested and versioned independently.
- A staging environment that mirrors production topology, so IaC changes get validated before touching real infrastructure.
- Automated secrets rotation testing — rotation configured but never exercised is a false sense of security.
- A cost-monitoring budget alert wired into the CI/CD pipeline so infrastructure changes that meaningfully shift spend get flagged before merge, not after the bill arrives.
