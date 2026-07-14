.PHONY: run docker-build test clean setup format lint help

LOG_LEVEL ?= DEBUG
PLUMBER_PORT ?= 8000
CONTAINER_PORT ?= 8000
DREDD_LOG_LEVEL ?= warning
LOCAL_IMAGE ?= yoshimotosamonji-monolith
BUILD_IMAGE ?= $(LOCAL_IMAGE)
GIT_COMMIT ?= $(shell git rev-parse --short HEAD)
COMPOSE_PROJECT_NAME ?= yoshimoto-samonji
DOCKER_NETWORK := $(COMPOSE_PROJECT_NAME)_yoshimoto-samonji

help:
	@echo "Available targets:"
	@echo "  make setup        - Install dev dependencies (air, lintr)"
	@echo "  make run          - Run plumber API locally (LOG_LEVEL=DEBUG by default)"
	@echo "  make test         - Run contract tests with docker-compose (docker-up required)"
	@echo "  make test-local   - Run contract tests against localhost (for 'make run')"
	@echo "  make format       - Format R code with air"
	@echo "  make lint         - Lint R code with lintr"
	@echo "  make docker-build - Build Docker image"
	@echo "  make clean        - Remove schema files"
	@echo ""
	@echo "Examples:"
	@echo "  LOG_LEVEL=INFO make run"
	@echo "  PLUMBER_PORT=9000 make test-local"
	@echo "  make docker-build && make test"

run:
	VALIDATE_RESPONSE=true \
	LOG_LEVEL=$(LOG_LEVEL) \
	OPENAPI_SPEC_PATH=./schema/openapi.yaml \
	PLUMBER_PORT=$(PLUMBER_DEV_PORT) \
	Rscript run.R

test:
	docker run --rm \
	  --network $(DOCKER_NETWORK) \
	  -v $$(pwd)/schema:/schema \
 	  -v $$(pwd)/../schemathesis.toml:/workspace/schemathesis.toml \
	  -v $$(pwd)/..:/workspace \
	  -w /workspace/.schemathesis \
	  ghcr.io/schemathesis/schemathesis:stable \
	  run /schema/openapi.yaml \
	  --url http://monolith:$(CONTAINER_PORT) \
	  --coverage-format html --coverage-report-html-path ./schema-coverage.html

test-local:
	docker run --rm \
	  -v $$(pwd)/schema:/schema \
	  -v $$(pwd)/../schemathesis.toml:/workspace/schemathesis.toml \
	  -v $$(pwd)/..:/workspace \
	  -w /workspace \
	  ghcr.io/schemathesis/schemathesis:stable \
	  run /schema/openapi.yaml \
	  --url http://host.docker.internal:$(PLUMBER_DEV_PORT) \
 	  --coverage-format html --coverage-report-html-path ./schema-coverage.html


docker-build:
	docker build --no-cache -t $(BUILD_IMAGE):$(GIT_COMMIT) -t $(BUILD_IMAGE):latest ./

clean:
	find . -name "*.Rhistory" -delete

setup:
	@echo "Installing dev dependencies..."
	curl -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh
	Rscript -e "if (!require('lintr', quietly = TRUE)) install.packages('lintr')"
	@echo "Dev dependencies installed"

format:
	air format $(CHECK) .

lint:
	Rscript -e "lintr::lint_dir('.')"
