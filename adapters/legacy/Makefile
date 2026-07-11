.PHONY: run docker-build test clean help

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
	@echo "  make run          - Run plumber API locally (LOG_LEVEL=DEBUG by default)"
	@echo "  make test         - Run contract tests with docker-compose (docker-up required)"
	@echo "  make test-local   - Run contract tests against localhost (for 'make run')"
	@echo "  make docker-build - Build Docker image"
	@echo "  make clean        - Remove schema files"
	@echo ""
	@echo "Examples:"
	@echo "  LOG_LEVEL=INFO make run"
	@echo "  PLUMBER_PORT=9000 make test-local"
	@echo "  make docker-build && make test"

run:
	LOG_LEVEL=$(LOG_LEVEL) OPENAPI_SPEC_PATH=../../schema/openapi.yaml PLUMBER_PORT=$(PLUMBER_DEV_PORT) Rscript run.R

test:
	docker run --rm \
	  --network $(DOCKER_NETWORK) \
	  -v $$(pwd)/../../schema:/schema \
	  -v $$(pwd)/../..:/workspace \
	  -w /workspace/.schemathesis \
	  ghcr.io/schemathesis/schemathesis:stable \
	  run /schema/openapi.yaml \
	  --url http://monolith:$(CONTAINER_PORT) \
	  --max-examples=100

test-local:
	docker run --rm \
	  -v $$(pwd)/../../schema:/schema \
	  -v $$(pwd)/../..:/workspace \
	  -w /workspace \
	  ghcr.io/schemathesis/schemathesis:stable \
	  run /schema/openapi.yaml \
	  --url http://host.docker.internal:$(PLUMBER_DEV_PORT) \
	  --max-examples=100

docker-build:
	docker build --no-cache -t $(BUILD_IMAGE):$(GIT_COMMIT) -t $(BUILD_IMAGE):latest ./

clean:
	find . -name "*.Rhistory" -delete
