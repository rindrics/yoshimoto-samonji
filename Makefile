.PHONY: docker-build docker-up docker-down docker-logs docker-clean docker-clean-build help

PLUMBER_PORT ?= 8000

help:
	@echo "Available targets:"
	@echo "  make docker-build      - Build Docker image"
	@echo "  make docker-up         - Build and start containers"
	@echo "  make docker-down       - Stop containers"
	@echo "  make docker-logs       - View container logs"
	@echo "  make docker-clean      - Remove image and build cache"
	@echo "  make docker-clean-build - Clean and rebuild image"
	@echo ""
	@echo "For adapter-specific commands, use:"
	@echo "  make -C adapters/legacy run"
	@echo "  make -C adapters/legacy schema"
	@echo "  make -C adapters/legacy clean"

docker-build:
	$(MAKE) -C adapters/legacy docker-build

docker-up:
	docker-compose up -d --no-build monolith

docker-down:
	docker-compose down

docker-logs:
	docker-compose logs -f monolith

docker-clean:
	docker image rm souzasamonji-monolith:latest || true
	docker builder prune -af

docker-clean-build: docker-clean docker-build
