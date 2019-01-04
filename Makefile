# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
GO := go

all: generate test vet lint install

install-dev-deps:
	$(GO) get golang.org/x/tools/cmd/cover
	$(GO) get github.com/golang/lint/golint
	$(GO) get github.com/mattn/goveralls

install:
	$(GO) install go.mozilla.org/autograph

build-container: generate
	docker build -t app:build .

echo-coverage:
	cat coverage.out

test-container:
	docker run --name autograph-dev --rm -u 0 --net host app:build make -C /go/src/go.mozilla.org/autograph install-dev-deps test

test-container-ci:
	docker run --name autograph-dev --rm -u 0 --net host app:build make -C /go/src/go.mozilla.org/autograph install-dev-deps test echo-coverage | tee test-container.out
	grep -A10000 'cat coverage.out' test-container.out | tail -n +2 | head -n -1 > coverage.out

run-container:
	docker run --name autograph-dev --rm -d --net host app:build

vendor:
	govend -u --prune
	#go get -u github.com/golang/dep/...
	#dep ensure -update
	# https://github.com/ThalesIgnite/crypto11/issues/9
	git checkout -f 2210ea80470825094edf8235b35f9565c7940555 vendor/github.com/ThalesIgnite/crypto11/
	rm -rf vendor/go.mozilla.org/autograph/  # don't vendor ourselves
	git add vendor/

tag: all
	git tag -s $(TAGVER) -a -m "$(TAGMSG)"

lint:
	golint go.mozilla.org/autograph
	golint go.mozilla.org/autograph/signer
	golint go.mozilla.org/autograph/signer/contentsignature
	golint go.mozilla.org/autograph/signer/xpi
	golint go.mozilla.org/autograph/signer/apk
	golint go.mozilla.org/autograph/signer/mar
	golint go.mozilla.org/autograph/signer/pgp
	golint go.mozilla.org/autograph/signer/gpg2

vet:
	$(GO) vet go.mozilla.org/autograph
	$(GO) vet go.mozilla.org/autograph/signer
	$(GO) vet go.mozilla.org/autograph/signer/apk
	$(GO) vet go.mozilla.org/autograph/signer/contentsignature
	$(GO) vet go.mozilla.org/autograph/signer/mar
	$(GO) vet go.mozilla.org/autograph/signer/xpi
	$(GO) vet go.mozilla.org/autograph/signer/apk
	$(GO) vet go.mozilla.org/autograph/signer/mar
	$(GO) vet go.mozilla.org/autograph/signer/pgp
	$(GO) vet go.mozilla.org/autograph/signer/gpg2

testautograph:
	$(GO) test -v -covermode=count -coverprofile=coverage_autograph.out go.mozilla.org/autograph

showcoverageautograph: testautograph
	$(GO) tool cover -html=coverage_autograph.out

testsigner:
	$(GO) test -v -covermode=count -coverprofile=coverage_signer.out go.mozilla.org/autograph/signer

showcoveragesigner: testsigner
	$(GO) tool cover -html=coverage_signer.out

testcs:
	$(GO) test -v -covermode=count -coverprofile=coverage_cs.out go.mozilla.org/autograph/signer/contentsignature

testmonitor:
	$(GO) test -v -covermode=count -coverprofile=coverage_monitor.out go.mozilla.org/autograph/tools/autograph-monitor

showcoveragecs: testcs
	$(GO) tool cover -html=coverage_cs.out

testxpi:
	$(GO) test -v -covermode=count -coverprofile=coverage_xpi.out go.mozilla.org/autograph/signer/xpi

showcoveragexpi: testxpi
	$(GO) tool cover -html=coverage_xpi.out

testapk:
	$(GO) test -v -covermode=count -coverprofile=coverage_apk.out go.mozilla.org/autograph/signer/apk

showcoverageapk: testapk
	$(GO) tool cover -html=coverage_apk.out

testmar:
	$(GO) test -v -covermode=count -coverprofile=coverage_mar.out go.mozilla.org/autograph/signer/mar

showcoveragemar: testmar
	$(GO) tool cover -html=coverage_mar.out

testpgp:
	$(GO) test -v -covermode=count -coverprofile=coverage_pgp.out go.mozilla.org/autograph/signer/pgp

showcoveragepgp: testpgp
	$(GO) tool cover -html=coverage_pgp.out

testgpg2:
	$(GO) test -v -covermode=count -coverprofile=coverage_gpg2.out go.mozilla.org/autograph/signer/gpg2

showcoveragegpg2: testgpg2
	$(GO) tool cover -html=coverage_gpg2.out

test: testautograph testsigner testcs testxpi testapk testmar testpgp testgpg2
	echo 'mode: count' > coverage.out
	grep -v mode coverage_*.out | cut -d ':' -f 2,3 >> coverage.out

showcoverage: test
	$(GO) tool cover -html=coverage.out

generate:
	$(GO) generate

dummy-statsd:
	nc -kluvw 0 localhost 8125

.PHONY: all dummy-statsd test generate vendor
