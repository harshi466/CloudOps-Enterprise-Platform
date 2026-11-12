.PHONY: test up down train tf-init tf-plan tf-apply tf-destroy
test:
	cd services/user-service && pip install -q -r requirements.txt -r requirements-dev.txt && pytest -q
	cd services/expense-service && pip install -q -r requirements.txt -r requirements-dev.txt && pytest -q
up:
	docker compose up --build
down:
	docker compose down -v
train:
	python ml/train.py
tf-init:
	cd terraform && terraform init
tf-plan:
	cd terraform && terraform plan -var-file=terraform.tfvars
tf-apply:
	cd terraform && terraform apply -var-file=terraform.tfvars
tf-destroy:
	cd terraform && terraform destroy -var-file=terraform.tfvars
