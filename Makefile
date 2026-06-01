# Build and tag Multica agent images (one tag per CLI variant).
#
# Examples:
#   make build-all
#   make build-claude IMAGE=ghcr.io/myorg/multica-agent TAG=v0.1.0
#   make build-all MULTICA_TAG=v0.1.12 TAG=latest

IMAGE ?= ghcr.io/multica-ai/multica-agent
TAG ?= latest
MULTICA_IMAGE ?= ghcr.io/multica-ai/multica-backend
MULTICA_TAG ?= latest

BUILD_ARGS := \
	--build-arg MULTICA_IMAGE=$(MULTICA_IMAGE) \
	--build-arg MULTICA_TAG=$(MULTICA_TAG)

DOCKERFILE := Dockerfile.agent

.PHONY: build-all build-claude build-cursor build-opencode
.PHONY: tag-claude tag-cursor tag-opencode

build-all: build-claude build-cursor build-opencode

build-claude:
	docker build -f $(DOCKERFILE) --target claude $(BUILD_ARGS) -t $(IMAGE)-claude:$(TAG) .

build-cursor:
	docker build -f $(DOCKERFILE) --target cursor $(BUILD_ARGS) -t $(IMAGE)-cursor:$(TAG) .

build-opencode:
	docker build -f $(DOCKERFILE) --target opencode $(BUILD_ARGS) -t $(IMAGE)-opencode:$(TAG) .

# Alias targets (same as build-*)
tag-claude: build-claude
tag-cursor: build-cursor
tag-opencode: build-opencode
