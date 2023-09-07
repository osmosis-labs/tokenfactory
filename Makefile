#!/usr/bin/make -f

VERSION := $(shell echo $(shell git describe --tags) | sed 's/^v//')
COMMIT := $(shell git log -1 --format='%H')

LEDGER_ENABLED ?= true
SDK_PACK := $(shell go list -m github.com/cosmos/cosmos-sdk | sed  's/ /\@/g')
BUILDDIR ?= $(CURDIR)/build
DOCKER := $(shell which docker)
E2E_UPGRADE_VERSION := "v19"
#SHELL := /bin/bash

# Go version to be used in docker images
GO_VERSION := $(shell cat go.mod | grep -E 'go [0-9].[0-9]+' | cut -d ' ' -f 2)
# currently installed Go version
GO_MODULE := $(shell cat go.mod | grep "module " | cut -d ' ' -f 2)
GO_MAJOR_VERSION = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f1)
GO_MINOR_VERSION = $(shell go version | cut -c 14- | cut -d' ' -f1 | cut -d'.' -f2)
# minimum supported Go version
GO_MINIMUM_MAJOR_VERSION = $(shell cat go.mod | grep -E 'go [0-9].[0-9]+' | cut -d ' ' -f2 | cut -d'.' -f1)
GO_MINIMUM_MINOR_VERSION = $(shell cat go.mod | grep -E 'go [0-9].[0-9]+' | cut -d ' ' -f2 | cut -d'.' -f2)
# message to be printed if Go does not meet the minimum required version
GO_VERSION_ERR_MSG = "ERROR: Go version $(GO_MINIMUM_MAJOR_VERSION).$(GO_MINIMUM_MINOR_VERSION)+ is required"

export GO111MODULE = on

# process build tags

build_tags = netgo
ifeq ($(LEDGER_ENABLED),true)
  ifeq ($(OS),Windows_NT)
    GCCEXE = $(shell where gcc.exe 2> NUL)
    ifeq ($(GCCEXE),)
      $(error gcc.exe not installed for ledger support, please install or set LEDGER_ENABLED=false)
    else
      build_tags += ledger
    endif
  else
    UNAME_S = $(shell uname -s)
    ifeq ($(UNAME_S),OpenBSD)
      $(warning OpenBSD detected, disabling ledger support (https://github.com/cosmos/cosmos-sdk/issues/1988))
    else
      GCC = $(shell command -v gcc 2> /dev/null)
      ifeq ($(GCC),)
        $(error gcc not installed for ledger support, please install or set LEDGER_ENABLED=false)
      else
        build_tags += ledger
      endif
    endif
  endif
endif

ifeq (cleveldb,$(findstring cleveldb,$(OSMOSIS_BUILD_OPTIONS)))
  build_tags += gcc
else ifeq (rocksdb,$(findstring rocksdb,$(OSMOSIS_BUILD_OPTIONS)))
  build_tags += gcc
endif
build_tags += $(BUILD_TAGS)
build_tags := $(strip $(build_tags))

whitespace :=
whitespace := $(whitespace) $(whitespace)
comma := ,
build_tags_comma_sep := $(subst $(whitespace),$(comma),$(build_tags))

# process linker flags

ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=osmosis \
		  -X github.com/cosmos/cosmos-sdk/version.AppName=osmosisd \
		  -X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
		  -X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT) \
		  -X "github.com/cosmos/cosmos-sdk/version.BuildTags=$(build_tags_comma_sep)"

ifeq (cleveldb,$(findstring cleveldb,$(OSMOSIS_BUILD_OPTIONS)))
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=cleveldb
else ifeq (rocksdb,$(findstring rocksdb,$(OSMOSIS_BUILD_OPTIONS)))
  ldflags += -X github.com/cosmos/cosmos-sdk/types.DBBackend=rocksdb
endif
ifeq (,$(findstring nostrip,$(OSMOSIS_BUILD_OPTIONS)))
  ldflags += -w -s
endif
ifeq ($(LINK_STATICALLY),true)
	ldflags += -linkmode=external -extldflags "-Wl,-z,muldefs -static"
endif
ldflags += $(LDFLAGS)
ldflags := $(strip $(ldflags))

BUILD_FLAGS := -tags "$(build_tags)" -ldflags '$(ldflags)'
# check for nostrip option
ifeq (,$(findstring nostrip,$(OSMOSIS_BUILD_OPTIONS)))
  BUILD_FLAGS += -trimpath
endif

# Note that this skips certain tests that are not supported on WSL
# This is a workaround to enable quickly running full unit test suite locally
# on WSL without failures. The failures are stemming from trying to upload
# wasm code. An OS permissioning issue.
is_wsl := $(shell uname -a | grep -i Microsoft)
ifeq ($(is_wsl),)
    # Not in WSL
    SKIP_WASM_WSL_TESTS := "false"
else
    # In WSL
    SKIP_WASM_WSL_TESTS := "true"
endif

###############################################################################
###                                  Build                                  ###
###############################################################################

check_version:
	@echo "Go version: $(GO_MAJOR_VERSION).$(GO_MINOR_VERSION)"
	@if [ $(GO_MAJOR_VERSION) -gt $(GO_MINIMUM_MAJOR_VERSION) ]; then \
		echo "Go version is sufficient"; \
		exit 0; \
	elif [ $(GO_MAJOR_VERSION) -lt $(GO_MINIMUM_MAJOR_VERSION) ]; then \
		echo '$(GO_VERSION_ERR_MSG)'; \
		exit 1; \
	elif [ $(GO_MINOR_VERSION) -lt $(GO_MINIMUM_MINOR_VERSION) ]; then \
		echo '$(GO_VERSION_ERR_MSG)'; \
		exit 1; \
	fi

all: install lint test

build: check_version go.sum
	mkdir -p $(BUILDDIR)/
	GOWORK=off go build -mod=readonly  $(BUILD_FLAGS) -o $(BUILDDIR)/ $(GO_MODULE)/cmd/osmosisd

build-all: check_version go.sum
	mkdir -p $(BUILDDIR)/
	GOWORK=off go build -mod=readonly $(BUILD_FLAGS) -o $(BUILDDIR)/ ./...

install: check_version go.sum
	GOWORK=off go install -mod=readonly $(BUILD_FLAGS) $(GO_MODULE)/cmd/osmosisd

install-with-autocomplete: check_version go.sum
	GOWORK=off go install -mod=readonly $(BUILD_FLAGS) $(GO_MODULE)/cmd/osmosisd
	@PARENT_SHELL=$$(ps -o ppid= -p $$PPID | xargs ps -o comm= -p); \
	if echo "$$PARENT_SHELL" | grep -q "zsh"; then \
		if ! grep -q ". <(osmosisd enable-cli-autocomplete zsh)" ~/.zshrc; then \
			echo ". <(osmosisd enable-cli-autocomplete zsh)" >> ~/.zshrc; \
			echo; \
			echo "Autocomplete enabled. Run 'source ~/.zshrc' to complete installation."; \
		else \
			echo; \
			echo "Autocomplete already enabled in ~/.zshrc"; \
		fi \
	elif echo "$$PARENT_SHELL" | grep -q "bash" && [ "$$(uname)" = "Darwin" ]; then \
		if ! grep -q -e "\. <(osmosisd enable-cli-autocomplete bash)" -e '\[\[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" \]\] && \. "/opt/homebrew/etc/profile.d/bash_completion.sh"' ~/.bash_profile; then \
			brew install bash-completion; \
			echo '[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ] && . "/opt/homebrew/etc/profile.d/bash_completion.sh"' >> ~/.bash_profile; \
			echo ". <(osmosisd enable-cli-autocomplete bash)" >> ~/.bash_profile; \
			echo; \
			echo; \
			echo "Autocomplete enabled. Run 'source ~/.bash_profile' to complete installation."; \
		else \
			echo "Autocomplete already enabled in ~/.bash_profile"; \
		fi \
	elif echo "$$PARENT_SHELL" | grep -q "bash" && [ "$$(uname)" = "Linux" ]; then \
		if ! grep -q ". <(osmosisd enable-cli-autocomplete bash)" ~/.bash_profile; then \
			sudo apt-get install -y bash-completion; \
			echo '[ -r "/etc/bash_completion" ] && . "/etc/bash_completion"' >> ~/.bash_profile; \
			echo ". <(osmosisd enable-cli-autocomplete bash)" >> ~/.bash_profile; \
			echo; \
			echo "Autocomplete enabled. Run 'source ~/.bash_profile' to complete installation."; \
		else \
			echo; \
			echo "Autocomplete already enabled in ~/.bash_profile"; \
		fi \
	else \
		echo "Shell or OS not recognized. Skipping autocomplete setup."; \
	fi


# Cross-building for arm64 from amd64 (or viceversa) takes
# a lot of time due to QEMU virtualization but it's the only way (afaik)
# to get a statically linked binary with CosmWasm

build-reproducible: build-reproducible-amd64 build-reproducible-arm64

build-reproducible-amd64: go.sum
	mkdir -p $(BUILDDIR)
	$(DOCKER) buildx create --name osmobuilder || true
	$(DOCKER) buildx use osmobuilder
	$(DOCKER) buildx build \
		--build-arg GO_VERSION=$(GO_VERSION) \
		--build-arg GIT_VERSION=$(VERSION) \
		--build-arg GIT_COMMIT=$(COMMIT) \
		--build-arg RUNNER_IMAGE=alpine:3.17 \
		--platform linux/amd64 \
		-t osmosis:local-amd64 \
		--load \
		-f Dockerfile .
	$(DOCKER) rm -f osmobinary || true
	$(DOCKER) create -ti --name osmobinary osmosis:local-amd64
	$(DOCKER) cp osmobinary:/bin/osmosisd $(BUILDDIR)/osmosisd-linux-amd64
	$(DOCKER) rm -f osmobinary

build-reproducible-arm64: go.sum
	mkdir -p $(BUILDDIR)
	$(DOCKER) buildx create --name osmobuilder || true
	$(DOCKER) buildx use osmobuilder
	$(DOCKER) buildx build \
		--build-arg GO_VERSION=$(GO_VERSION) \
		--build-arg GIT_VERSION=$(VERSION) \
		--build-arg GIT_COMMIT=$(COMMIT) \
		--build-arg RUNNER_IMAGE=alpine:3.17 \
		--platform linux/arm64 \
		-t osmosis:local-arm64 \
		--load \
		-f Dockerfile .
	$(DOCKER) rm -f osmobinary || true
	$(DOCKER) create -ti --name osmobinary osmosis:local-arm64
	$(DOCKER) cp osmobinary:/bin/osmosisd $(BUILDDIR)/osmosisd-linux-arm64
	$(DOCKER) rm -f osmobinary

build-linux: go.sum
	LEDGER_ENABLED=false GOOS=linux GOARCH=amd64 $(MAKE) build

build-contract-tests-hooks:
	mkdir -p $(BUILDDIR)
	go build -mod=readonly $(BUILD_FLAGS) -o $(BUILDDIR)/ ./cmd/contract_tests

go-mod-cache: go.sum
	@echo "--> Download go modules to local cache"
	@go mod download

go.sum: go.mod
	@echo "--> Ensure dependencies have not been modified"
	@GOWORK=off go mod verify

draw-deps:
	@# requires brew install graphviz or apt-get install graphviz
	go get github.com/RobotsAndPencils/goviz
	@goviz -i ./cmd/osmosisd -d 2 | dot -Tpng -o dependency-graph.png

clean:
	rm -rf $(CURDIR)/artifacts/

distclean: clean
	rm -rf vendor/

###############################################################################
###                           Dependency Updates                            ###
###############################################################################

VERSION := 
MODFILES := ./go.mod ./osmoutils/go.mod ./osmomath/go.mod ./x/epochs/go.mod ./x/ibc-hooks/go.mod ./tests/cl-genesis-positions/go.mod ./tests/cl-go-client/go.mod
# run with VERSION argument specified
# e.g) make update-sdk-version VERSION=v0.45.1-0.20230523200430-193959b898ec
# This will change sdk dependencyu version for go.mod in root directory + all sub-modules in this repo.
update-sdk-version:
	@if [ -z "$(VERSION)" ]; then \
		echo "VERSION not set"; \
		exit 1; \
	fi
	@echo "Updating version to $(VERSION)"
	@for modfile in $(MODFILES); do \
		if [ -e "$$modfile" ]; then \
			sed -i '' 's|github.com/osmosis-labs/cosmos-sdk v[0-9a-z.\-]*|github.com/osmosis-labs/cosmos-sdk $(VERSION)|g' $$modfile; \
			cd `dirname $$modfile`; \
			go mod tidy; \
			cd - > /dev/null; \
		else \
			echo "File $$modfile does not exist"; \
		fi; \
	done

###############################################################################
###                                  Proto                                  ###
###############################################################################

proto-all: proto-format proto-gen

proto:
	@echo
	@echo "=========== Generate Message ============"
	@echo
	./scripts/protocgen.sh
	@echo
	@echo "=========== Generate Complete ============"
	@echo

test:
	@go test -v ./x/...

docs:
	@echo
	@echo "=========== Generate Message ============"
	@echo
	./scripts/generate-docs.sh

	statik -src=client/docs/static -dest=client/docs -f -m
	@if [ -n "$(git status --porcelain)" ]; then \
        echo "\033[91mSwagger docs are out of sync!!!\033[0m";\
        exit 1;\
    else \
        echo "\033[92mSwagger docs are in sync\033[0m";\
    fi
	@echo
	@echo "=========== Generate Complete ============"
	@echo
.PHONY: docs

protoVer=v0.9
protoImageName=osmolabs/osmo-proto-gen:$(protoVer)
containerProtoGen=cosmos-sdk-proto-gen-$(protoVer)
containerProtoFmt=cosmos-sdk-proto-fmt-$(protoVer)

proto-gen:
	@echo "Generating Protobuf files"
	@$(protoImage) sh ./scripts/protocgen.sh

proto-format:
	@echo "Formatting Protobuf files"
	@if docker ps -a --format '{{.Names}}' | grep -Eq "^${containerProtoFmt}$$"; then docker start -a $(containerProtoFmt); else docker run --name $(containerProtoFmt) -v $(CURDIR):/workspace --workdir /workspace tendermintdev/docker-build-proto \
		find ./ -not -path "./third_party/*" -name "*.proto" -exec clang-format -i {} \; ; fi

proto-image-build:
	@DOCKER_BUILDKIT=1 docker build -t $(protoImageName) -f ./proto/Dockerfile ./proto

proto-image-push:
	docker push $(protoImageName)
