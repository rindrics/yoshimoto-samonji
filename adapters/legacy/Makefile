.PHONY: run schema docker-build docker-up docker-down docker-logs clean help

PLUMBER_PORT ?= 8000

help:
	@echo "Available targets:"
	@echo "  make run          - Run plumber API locally"
	@echo "  make schema       - Generate OpenAPI schema"
	@echo "  make docker-build - Build Docker image"
	@echo "  make docker-up    - Start containers with docker-compose"
	@echo "  make docker-down  - Stop containers"
	@echo "  make docker-logs  - View container logs"
	@echo "  make clean        - Remove schema files"

run:
	PLUMBER_PORT=$(PLUMBER_PORT) Rscript run.R

schema:
	Rscript generate_schema.R

docker-build:
	docker-compose build monolith

docker-up:
	docker-compose up -d monolith

docker-down:
	docker-compose down

docker-logs:
	docker-compose logs -f monolith

clean:
	rm -f ../../schema/openapi.json
	find . -name "*.Rhistory" -delete
