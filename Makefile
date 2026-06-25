# Build and tag Multica agent images (one tag per CLI variant).
#
# `build-base` produces a reusable base image; the variant targets chain
# on it via AGENT_BASE_IMAGE, so running `make build-all` builds the
# base once and then only the thin CLI-install layer for each variant.
# If you'd rather build each variant fully from scratch (slower, no
# base reuse), run the individual targets with `BUILD_BASE=` cleared.
#
# Examples:
#   make build-all
#   make build-claude IMAGE=ghcr.io/myorg/multica-agent TAG=v0.1.0
#   make build-all MULTICA_TAG=v0.1.12 TAG=latest
#   make build-claude BUILD_BASE=    # skip base reuse, build claude standalone

IMAGE ?= ghcr.io/sapk/multica-agent
TAG ?= latest
MULTICA_IMAGE ?= ghcr.io/multica-ai/multica-backend
MULTICA_TAG ?= latest
# Set BUILD_BASE= to skip the base-extraction optimisation and build
# each variant from scratch. Default: chain on $(IMAGE)-base:$(TAG).
BUILD_BASE ?= $(IMAGE)-base:$(TAG)

export DOCKER_BUILDKIT := 1
export BUILDKIT_PROGRESS := plain

DOCKERFILE := Dockerfile.agent

.PHONY: build-all build-base build-claude build-cursor build-opencode build-codex build-agy
.PHONY: tag-claude tag-cursor tag-opencode tag-codex tag-agy

build-all: build-base build-claude build-cursor build-opencode build-codex build-agy

build-base:
	docker build -f $(DOCKERFILE) --target base \
		--pull \
		--build-arg MULTICA_IMAGE=$(MULTICA_IMAGE) \
		--build-arg MULTICA_TAG=$(MULTICA_TAG) \
		-t $(IMAGE)-base:$(TAG) .

VARIANT_ARGS := \
	--pull \
	--build-arg MULTICA_IMAGE=$(MULTICA_IMAGE) \
	--build-arg MULTICA_TAG=$(MULTICA_TAG)
ifdef BUILD_BASE
VARIANT_ARGS += --build-arg AGENT_BASE_IMAGE=$(BUILD_BASE)
endif

build-claude: build-base
	docker build -f $(DOCKERFILE) --target claude $(VARIANT_ARGS) -t $(IMAGE)-claude:$(TAG) .

build-cursor: build-base
	docker build -f $(DOCKERFILE) --target cursor $(VARIANT_ARGS) -t $(IMAGE)-cursor:$(TAG) .

build-opencode: build-base
	docker build -f $(DOCKERFILE) --target opencode $(VARIANT_ARGS) -t $(IMAGE)-opencode:$(TAG) .

build-codex: build-base
	docker build -f $(DOCKERFILE) --target codex $(VARIANT_ARGS) -t $(IMAGE)-codex:$(TAG) .

build-agy: build-base
	docker build -f $(DOCKERFILE) --target agy $(VARIANT_ARGS) -t $(IMAGE)-agy:$(TAG) .

# Alias targets (same as build-*)
tag-claude: build-claude
tag-cursor: build-cursor
tag-opencode: build-opencode
tag-codex: build-codex
tag-agy: build-agy
