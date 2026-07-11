.PHONY: run docker-build test clean help

LOG_LEVEL ?= DEBUG
PLUMBER_PORT ?= 8000
CONTAINER_PORT ?= 8000
DREDD_LOG_LEVEL ?= warning
LOCAL_IMAGE ?= yoshimotosamonji-monolith
BUILD_IMAGE ?= $(LOCAL_IMAGE)
GIT_COMMIT ?= $(shell git rev-parse --short HEAD)
# Get repo name from git or directory name
REPO_NAME ?= $(shell git rev-parse --show-toplevel 2>/dev/null | xargs basename || basename $$(pwd)/../..)
DOCKER_NETWORK := $(REPO_NAME)_yoshimoto-samonji

help:
	@echo "Available targets:"
	@echo "  make run          - Run plumber API locally (LOG_LEVEL=DEBUG by default)"
	@echo "  make test         - Run contract tests with Schemathesis"
	@echo "  make docker-build - Build Docker image"
	@echo "  make clean        - Remove schema files"
	@echo ""
	@echo "Examples:"
	@echo "  LOG_LEVEL=INFO make run"
	@echo "  LOG_LEVEL=ERROR make run"
	@echo "  PLUMBER_PORT=9000 make test"

run:
	PLUMBER_PORT=$(PLUMBER_PORT) LOG_LEVEL=$(LOG_LEVEL) OPENAPI_SPEC_PATH=../../schema/openapi.yaml Rscript run.R

test:
	docker run --rm \
	  --network $(DOCKER_NETWORK) \
	  -v $$(pwd)/../../schema:/schema \
	  -v $$(pwd)/../..:/workspace \
	  -w /workspace \
	  ghcr.io/schemathesis/schemathesis:stable \
	  run /schema/openapi.yaml \
	  --url http://monolith:$(CONTAINER_PORT) \
	  --max-examples=100

docker-build:
	docker build --no-cache -t $(BUILD_IMAGE):$(GIT_COMMIT) -t $(BUILD_IMAGE):latest ./

clean:
	find . -name "*.Rhistory" -delete
