# Build and tag Multica agent images (one tag per CLI variant).
#
# Examples:
#   make build-all
#   make build-claude IMAGE=ghcr.io/myorg/multica-agent TAG=v0.1.0
#   make build-all MULTICA_TAG=v0.1.12 TAG=latest

IMAGE ?= ghcr.io/sapk/multica-agent
TAG ?= latest
MULTICA_IMAGE ?= ghcr.io/multica-ai/multica-backend
MULTICA_TAG ?= latest

export DOCKER_BUILDKIT := 1
export BUILDKIT_PROGRESS := plain

BUILD_ARGS := \
	--pull \
	--build-arg MULTICA_IMAGE=$(MULTICA_IMAGE) \
	--build-arg MULTICA_TAG=$(MULTICA_TAG)

DOCKERFILE := Dockerfile.agent

.PHONY: build-all build-claude build-cursor build-opencode build-codex build-gemini build-agy
.PHONY: tag-claude tag-cursor tag-opencode tag-codex tag-gemini tag-agy

build-all: build-claude build-cursor build-opencode build-codex build-gemini build-agy

build-claude:
	docker build -f $(DOCKERFILE) --target claude $(BUILD_ARGS) -t $(IMAGE)-claude:$(TAG) .

build-cursor:
	docker build -f $(DOCKERFILE) --target cursor $(BUILD_ARGS) -t $(IMAGE)-cursor:$(TAG) .

build-opencode:
	docker build -f $(DOCKERFILE) --target opencode $(BUILD_ARGS) -t $(IMAGE)-opencode:$(TAG) .

build-codex:
	docker build -f $(DOCKERFILE) --target codex $(BUILD_ARGS) -t $(IMAGE)-codex:$(TAG) .

build-gemini:
	docker build -f $(DOCKERFILE) --target gemini $(BUILD_ARGS) -t $(IMAGE)-gemini:$(TAG) .

build-agy:
	docker build -f $(DOCKERFILE) --target agy $(BUILD_ARGS) -t $(IMAGE)-agy:$(TAG) .

# Alias targets (same as build-*)
tag-claude: build-claude
tag-cursor: build-cursor
tag-opencode: build-opencode
tag-codex: build-codex
tag-gemini: build-gemini
tag-agy: build-agy
