# Deployment Guide (step by step)

## 0. Prerequisites
Install: AWS CLI v2, Terraform >= 1.5, Docker, kubectl, Python 3.12, git. (Optional: minikube.)

1. Create an AWS account, **enable MFA on the root user**, then create an IAM admin user for yourself (with MFA).
2. `aws configure` with that user's credentials (or use `aws sso login`).
3. **Billing alerts:** Billing console -> Billing preferences -> enable alert emails. (Terraform also creates a Budget.)

## 1. Run locally first
```bash
make test
make up        # open http://localhost:8080, register, add expenses
```

## 2. Provision infrastructure (Modules 1, 2, 3, 4, 5, 7)
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars    # edit alert_email
terraform init
terraform plan
terraform apply
```
Confirm the **SNS subscription email** AWS sends you. Note the outputs (`terraform output`).

Check: open `web_server_url` (EC2 nginx page), `curl $(terraform output -raw serverless_api_url)/health`.

## 3. Train and publish the ML model
```bash
python ml/train.py --upload-bucket $(terraform output -raw datalake_bucket)
curl -X POST $(terraform output -raw predict_url) -H 'Content-Type: application/json' \
     -d '{"monthly_totals":[20000,20500,21000]}'
```

## 4. Build and push container images
```bash
REGION=ap-south-1
REG=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.$REGION.amazonaws.com
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $REG
for s in user-service expense-service; do
  docker build -t $REG/cloudops-dev/$s:latest services/$s && docker push $REG/cloudops-dev/$s:latest
done
docker build -t $REG/cloudops-dev/frontend:latest frontend && docker push $REG/cloudops-dev/frontend:latest
```

## 5. Deploy to Kubernetes

### Option A: free, local (minikube)
```bash
minikube start && minikube addons enable ingress
# build images straight into minikube
eval $(minikube docker-env)
docker build -t user-service:local services/user-service
docker build -t expense-service:local services/expense-service
docker build -t frontend:local frontend
# point manifests at local images
sed -i 's#ECR_REGISTRY/\(.*\):latest#\1:local#' k8s/10-*.yaml k8s/20-frontend.yaml
kubectl apply -f k8s/00-namespace.yaml -f k8s/local-postgres.yaml
kubectl -n expense-app create secret generic app-secrets \
  --from-literal=DATABASE_URL='postgresql://app:localpass@postgres:5432/expenses' \
  --from-literal=JWT_SECRET=$(openssl rand -hex 32)
kubectl apply -k k8s
minikube tunnel   # then open http://127.0.0.1
```
On minikube the KINESIS/S3/predict settings in `k8s/01-config.yaml` are not reachable; the app degrades gracefully (events are skipped, forecast uses the built-in fallback).

### Option B: EKS (costs money, delete afterwards)
```bash
# terraform.tfvars:  enable_nat = true  and  enable_eks = true   ->  terraform apply
aws eks update-kubeconfig --name $(terraform output -raw eks_cluster_name) --region ap-south-1
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.2/deploy/static/provider/aws/deploy.yaml
sed -i "s#ECR_REGISTRY/#$REG/cloudops-dev/#" k8s/*.yaml
# edit k8s/01-config.yaml with terraform outputs (receipts bucket, predict URL)
SECRET=$(aws secretsmanager get-secret-value --secret-id cloudops-dev/db-credentials --query SecretString --output text)
kubectl apply -f k8s/00-namespace.yaml
kubectl -n expense-app create secret generic app-secrets \
  --from-literal=DATABASE_URL="$(echo $SECRET | python3 -c 'import sys,json;print(json.load(sys.stdin)["url"])')" \
  --from-literal=JWT_SECRET="$(openssl rand -hex 32)"
kubectl apply -f k8s/01-config.yaml
kubectl apply -k k8s
kubectl -n expense-app get pods,svc,ingress
```
Open the Load Balancer hostname from `kubectl -n ingress-nginx get svc`. The real Secret is created with the command above; `k8s/secret.example.yaml` is only a template and is not applied.

## 6. Streaming + analytics demo
```bash
python streaming/producer.py --stream $(terraform output -raw kinesis_stream) --count 200
```
Wait ~2 minutes for Firehose, then run the SQL in `streaming/athena_queries.sql` in the Athena console (workgroup `cloudops-dev-wg`).

## 7. CI/CD
1. Push the repo to GitHub.
2. Set `github_repo = "<user>/<repo>"` in tfvars, `terraform apply`, copy `github_ci_role_arn`.
3. Repo -> Settings -> Secrets: `AWS_ROLE_ARN`; Variables: `EKS_CLUSTER` (only if using EKS), `ALERT_EMAIL`.
4. Push to `main`: pipeline runs **test -> build -> scan -> push to ECR -> deploy Lambda -> deploy to EKS**.

## 8. Monitoring screenshots
CloudWatch -> Dashboards -> `cloudops-dev-overview`; Alarms; Budgets; Logs Insights.
Trigger an alarm for the screenshot: `aws lambda invoke --function-name cloudops-dev-api --payload '{"routeKey":"BAD"}' out.json` (returns 404, not error), or stress the VM via SSM: `stress`/`yes > /dev/null &`.

## 9. No-code app
Follow **docs/NOCODE_GUIDE.md**.

## 10. CLEAN UP (important)
```bash
kubectl delete -k k8s            # if you used EKS
cd terraform && terraform destroy
```
Then check the EC2, RDS, NAT Gateway, EKS and Elastic IP consoles for leftovers.
