module github.com/mozilla-services/autograph/tools/autograph-monitor

go 1.15

require (
	github.com/aws/aws-lambda-go v1.26.0
	github.com/golang/mock v1.6.0
	github.com/mozilla-services/autograph v0.0.0-20210910141803-8eb80cd03e48
	github.com/mozilla-services/autograph/verifier/contentsignature v0.0.0-20210910141803-8eb80cd03e48
	go.mozilla.org/hawk v0.0.0-20190327210923-a483e4a7047e
	go.mozilla.org/mar v0.0.0-20200124173325-c51ce05c9f3d
)

replace github.com/mozilla-services/autograph => ../../.
