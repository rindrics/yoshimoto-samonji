.PHONY: run docker-build clean help

help:
	@echo "Available targets:"
	@echo "  make run          - Run plumber API locally"
	@echo "  make docker-build - Build Docker image"
	@echo "  make clean        - Remove schema files"
	@echo ""
	@echo "For docker-compose commands, use make from project root:"
	@echo "  make docker-up    - Build and start containers"
	@echo "  make docker-down  - Stop containers"
	@echo "  make docker-logs  - View container logs"

run:
	PLUMBER_PORT=$(PLUMBER_PORT) OPENAPI_SPEC_PATH=../../schema/openapi.yaml Rscript run.R

docker-build:
	docker build --no-cache -t ghcr.io/rindrics/yoshimoto-samonji/monolith:latest ./

clean:
	find . -name "*.Rhistory" -delete
