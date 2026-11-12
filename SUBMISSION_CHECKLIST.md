# Submission Checklist (maps to the 7 Final Deliverables)

| # | Deliverable | Where it is | Evidence you must add |
|---|---|---|---|
| 1 | Full Cloud Architecture Document | `docs/ARCHITECTURE.md` (export to PDF/Word) | Draw the diagrams in draw.io/Mermaid image; add your own screenshots |
| 2 | IaC scripts | `terraform/` | `terraform apply` output screenshot |
| 3 | CI/CD pipeline files | `.github/workflows/*.yml`, `Jenkinsfile` | Screenshot of a green pipeline run |
| 4 | Docker images / K8s manifests | `services/*/Dockerfile`, `frontend/Dockerfile`, `k8s/` | `docker images`, `kubectl get pods,svc,ingress` |
| 5 | Monitoring dashboard + alert screenshots | CloudWatch (created by `monitoring.tf`) | Dashboard, alarm in ALARM state, email received, Budget page |
| 6 | Deployed cloud app (URL + screenshots) | Ingress/EC2/API Gateway URLs from `terraform output` | App login, add expense, forecast |
| 7 | Big Data + ML pipeline summary | `docs/ARCHITECTURE.md` section 8, `ml/`, `streaming/` | Kinesis metrics, Athena result, `/predict` response |

## Module coverage

| Module | Done by |
|---|---|
| 1 Infrastructure & virtualization | `ec2.tf`, virtualization-vs-container table |
| 2 Networking, storage, data | `vpc.tf`, `security.tf`, `s3.tf` (lifecycle), `rds.tf` |
| 3 Serverless & microservices | `lambda.tf`, `services/`, `k8s/` |
| 4 Security, IAM, monitoring | `iam.tf`, encryption settings, `monitoring.tf` |
| 5 IaC & automation | `terraform/`, Dockerfiles, `Jenkinsfile`, GitHub Actions |
| 6 CI/CD | `.github/workflows/ci-cd.yml` (build -> test -> deploy) |
| 7 Big data, AI, streaming | `streaming.tf`, `ml/`, `streaming/`, Lambda `/predict` |
| 8 No-code + integration | `nocode/`, `docs/NOCODE_GUIDE.md` |

## Be ready to explain in your viva
* Why DB is in a private subnet and how the app reaches it (security groups, subnet routing).
* What a permission boundary is and why least privilege matters.
* Difference between VM and container; between Lambda and Kubernetes.
* How a `git push` reaches production (pipeline stages).
* Why Kinesis -> Firehose -> S3 -> Athena is a serverless data warehouse pattern.
