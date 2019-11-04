FROM golang:1.13.4-buster
EXPOSE 8000

RUN addgroup --gid 10001 app \
      && \
      adduser --gid 10001 --uid 10001 \
      --home /app --shell /sbin/nologin \
      --disabled-password app \
      && \
      apt update && \
      apt -y upgrade && \
      apt -y install libltdl-dev gpg libncurses5 apksigner && \
      apt-get clean

# import the RDS CA bundle
# https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html#PostgreSQL.Concepts.General.SSL
RUN curl -o /tmp/rds-combined-ca-bundle.pem https://s3.amazonaws.com/rds-downloads/rds-combined-ca-bundle.pem && \
    openssl x509 -in /tmp/rds-combined-ca-bundle.pem -inform PEM -out /usr/local/share/ca-certificates/rds-combined-ca-bundle.crt && \
    rm -f /tmp/rds-combined-ca-bundle.pem && \
    update-ca-certificates

ADD . /go/src/go.mozilla.org/autograph
ADD autograph.yaml /app
ADD version.json /app

RUN go install go.mozilla.org/autograph

USER app
WORKDIR /app
CMD /go/bin/autograph
