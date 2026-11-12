# CloudOps Enterprise Platform: Expense Tracker on AWS

A production-style, cloud-native reference implementation covering all 8 capstone modules:
IaaS, networking, storage, serverless, microservices on Kubernetes, IAM/security, monitoring,
Infrastructure-as-Code, CI/CD, streaming + big data + ML, and a no-code front-end.

**Application:** multi-user Expense Tracker (login, add/list expenses, summaries, receipt upload, ML next-month forecast).

## Repository layout

| Path | Contents | Module |
|---|---|---|
| `terraform/` | Complete AWS infrastructure as code | 1, 2, 3, 4, 5, 7 |
| `services/user-service`, `services/expense-service` | Flask microservices + Dockerfiles + tests | 3, 6 |
| `frontend/` | Web UI + nginx container | 3 |
| `k8s/` | Deployments, Services, HPA, Ingress, NetworkPolicy, Kustomize | 3 |
| `lambda/` | S3-triggered receipt processor + API (ML inference) | 3, 7 |
| `ml/`, `streaming/` | Model training, Kinesis producer, Athena SQL | 7 |
| `.github/workflows/`, `Jenkinsfile` | CI/CD pipelines | 5, 6 |
| `nocode/openapi.yaml`, `docs/NOCODE_GUIDE.md` | OutSystems / Mendix integration | 8 |
| `docs/` | Architecture document, deployment guide, checklist | Deliverables |

## Quick start (local, no AWS needed)

```bash
make test        # unit + integration tests for both services
make up          # docker compose: Postgres + 2 services + frontend -> http://localhost:8080
```

## Deploy on AWS

See **docs/DEPLOYMENT_GUIDE.md** for the full step-by-step. In short:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # set alert_email
terraform init && terraform apply
```

## Cost warning
Default settings stay close to free tier (EC2 t3.micro, RDS db.t3.micro, serverless pay-per-use).
NAT Gateway and EKS are **off by default** (they cost money). Run `terraform destroy` when done.
