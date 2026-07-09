.PHONY: run docker-build clean help

LOG_LEVEL ?= DEBUG

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
	PLUMBER_PORT=$(PLUMBER_PORT) LOG_LEVEL=$(LOG_LEVEL) OPENAPI_SPEC_PATH=../../schema/openapi.yaml Rscript run.R

help:
	@echo "Available targets:"
	@echo "  make run          - Run plumber API locally (LOG_LEVEL=DEBUG by default)"
	@echo "  make docker-build - Build Docker image"
	@echo "  make clean        - Remove schema files"
	@echo ""
	@echo "Examples:"
	@echo "  LOG_LEVEL=INFO make run"
	@echo "  LOG_LEVEL=ERROR make run"

docker-build:
	docker build --no-cache -t ghcr.io/rindrics/yoshimoto-samonji/monolith:latest ./

clean:
	find . -name "*.Rhistory" -delete
