.PHONY: run docker-build dredd clean help

LOG_LEVEL ?= DEBUG
PLUMBER_PORT ?= 8000
DREDD_LOG_LEVEL ?= warning
LOCAL_IMAGE ?= yoshimotosamonji-monolith
BUILD_IMAGE ?= $(LOCAL_IMAGE)
GIT_COMMIT ?= $(shell git rev-parse --short HEAD)

help:
	@echo "Available targets:"
	@echo "  make run          - Run plumber API locally (LOG_LEVEL=DEBUG by default)"
	@echo "  make dredd        - Run contract tests with Dredd"
	@echo "  make docker-build - Build Docker image"
	@echo "  make clean        - Remove schema files"
	@echo ""
	@echo "Examples:"
	@echo "  LOG_LEVEL=INFO make run"
	@echo "  LOG_LEVEL=ERROR make run"
	@echo "  PLUMBER_PORT=9000 DREDD_LOG_LEVEL=debug make dredd"

run:
	PLUMBER_PORT=$(PLUMBER_PORT) LOG_LEVEL=$(LOG_LEVEL) OPENAPI_SPEC_PATH=../../schema/openapi.yaml Rscript run.R

dredd:
	pnpm exec dredd ../../schema/openapi.yaml http://localhost:$(PLUMBER_PORT) --loglevel=$(DREDD_LOG_LEVEL)

docker-build:
	docker build --no-cache -t $(BUILD_IMAGE):$(GIT_COMMIT) -t $(BUILD_IMAGE):latest ./

clean:
	find . -name "*.Rhistory" -delete
