.PHONY: help build up down logs clean migrate test

help:
	@echo "Whoosh Development Commands:"
	@echo "  make build      - Build Docker images"
	@echo "  make up         - Start all services"
	@echo "  make down       - Stop all services"
	@echo "  make logs       - Show logs from all services"
	@echo "  make clean      - Remove containers and volumes"
	@echo "  make migrate    - Run Django migrations"
	@echo "  make test       - Run tests"

build:
	docker-compose build

up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs -f

clean:
	docker-compose down -v
	docker system prune -f

migrate:
	docker-compose exec django-api python manage.py migrate

test:
	docker-compose exec django-api python manage.py test

# Django specific commands
django-shell:
	docker-compose exec django-api python manage.py shell

django-createsuperuser:
	docker-compose exec django-api python manage.py createsuperuser

# Go specific commands
go-build:
	cd services/go-game-edge && go build -o bin/server ./cmd/server

go-run:
	cd services/go-game-edge && go run ./cmd/server

# Terraform commands
tf-init:
	cd infrastructure/terraform && terraform init

tf-plan:
	cd infrastructure/terraform && terraform plan

tf-apply:
	cd infrastructure/terraform && terraform apply

tf-destroy:
	cd infrastructure/terraform && terraform destroy

