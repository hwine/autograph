# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

PROJECT		:= go.mozilla.org/autograph
GO 			:= GO15VENDOREXPERIMENT=1 go
GOGETTER	:= GOPATH=$(shell pwd)/.tmpdeps go get -d
GOLINT 		:= golint

all: test vet generate install

install:
	$(GO) install $(PROJECT)

vendor:
	go get -u github.com/golang/dep/...
	dep ensure -update

tag: all
	git tag -s $(TAGVER) -a -m "$(TAGMSG)"

lint:
	$(GOLINT) $(PROJECT)

vet:
	$(GO) vet $(PROJECT)

test:
	$(GO) test -covermode=count -coverprofile=coverage.out go.mozilla.org/autograph
	$(GO) test -covermode=count -coverprofile=coverage.out go.mozilla.org/autograph/signer/...


showcoverage: test
	$(GO) tool cover -html=coverage.out

generate:
	$(GO) generate

.PHONY: all test generate clean autograph vendor
