.PHONY: docker-build docker-up docker-down docker-logs docker-clean docker-clean-build prod-up prod-down prod-logs help

PLUMBER_PORT ?= 8000
LOCAL_IMAGE ?= yoshimotosamonji-monolith
GIT_COMMIT ?= $(shell git rev-parse --short HEAD)

# Support both 'docker compose' and 'docker-compose' commands
DOCKER_COMPOSE := docker compose
ifeq ($(shell command -v docker-compose 2>/dev/null && echo 1),1)
  DOCKER_COMPOSE := docker-compose
endif

help:
	@echo "Available targets (dev/CI):"
	@echo "  make docker-build      - Build Docker image"
	@echo "  make docker-up         - Build and start containers"
	@echo "  make docker-down       - Stop containers"
	@echo "  make docker-logs       - View container logs"
	@echo "  make docker-clean      - Remove image and build cache"
	@echo "  make docker-clean-build - Clean and rebuild image"
	@echo ""
	@echo "Production targets:"
	@echo "  make prod-up           - Start production containers (pulls from registry)"
	@echo "  make prod-down         - Stop production containers"
	@echo "  make prod-logs         - View production container logs"
	@echo ""
	@echo "For adapter-specific commands, use:"
	@echo "  make -C adapters/legacy run"
	@echo "  make -C adapters/legacy clean"

docker-build:
	$(MAKE) -C adapters/legacy docker-build

docker-up:
	MONOLITH_IMAGE=$(LOCAL_IMAGE):$(GIT_COMMIT) $(DOCKER_COMPOSE) up -d --no-build monolith

docker-down:
	$(DOCKER_COMPOSE) down

docker-logs:
	$(DOCKER_COMPOSE) logs -f monolith

docker-clean:
	docker image rm $(LOCAL_IMAGE):$(GIT_COMMIT) $(LOCAL_IMAGE):latest || true
	docker builder prune -af

docker-clean-build: docker-clean docker-build

prod-up:
	PULL_POLICY=always MONOLITH_IMAGE=ghcr.io/rindrics/yoshimoto-samonji/monolith:latest $(DOCKER_COMPOSE) up -d monolith

prod-down:
	$(DOCKER_COMPOSE) down

prod-logs:
	$(DOCKER_COMPOSE) logs -f monolith
