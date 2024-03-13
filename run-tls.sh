#!/bin/bash
set -euo pipefail

## Requirements
# - cosign
# - crane
# - go

# Sample run - assumptions:
# 1) $CERT_BASE is the directory with certificates - adjust the file name as needed
# 2) change the value of TIMESTAMP_SERVER_URL to the URL of the timestamp server started with TLS credentials
#
# TIMESTAMP_CLIENT_CACERT=$CERT_BASE/cacert.pem TIMESTAMP_CLIENT_CERT=$CERT_BASE/cert.pem TIMESTAMP_CLIENT_KEY=$CERT_BASE/key.pem TIMESTAMP_SERVER_NAME=change.to.real.server.name TIMESTAMP_SERVER_URL=https://freetsa.org/tsr bash -x ./run.sh |& tee /tmp/out

TIMESTAMP_SERVER_URL=${TIMESTAMP_SERVER_URL:="https://freetsa.org/tsr"}
IMG=${IMAGE_URI_DIGEST:-}
if [[ "$#" -ge 1 ]]; then
	IMG=$1
elif [[ -z "${IMG}" ]]; then
	# Upload an image to ttl.sh - commands from https://docs.sigstore.dev/cosign/keyless/
	SRC_IMAGE=busybox
	SRC_DIGEST=$(crane digest busybox)
	IMAGE_URI=ttl.sh/$(uuidgen | head -c 8 | tr 'A-Z' 'a-z')
	crane cp $SRC_IMAGE@$SRC_DIGEST $IMAGE_URI:3h
	IMG=$IMAGE_URI@$SRC_DIGEST
fi

echo "IMG (IMAGE_URI_DIGEST): $IMG, TIMESTAMP_SERVER_URL: $TIMESTAMP_SERVER_URL"

GOBIN=/tmp GOPROXY=https://proxy.golang.org,direct go install -v github.com/dmitris/gencert@latest

rm -f *.pem import-cosign.* key.pem


# use gencert to generate CA, keys and certificates
echo "generate keys and certificates with gencert"

passwd=$(uuidgen | head -c 32 | tr 'A-Z' 'a-z')
rm -f *.pem import-cosign.* && /tmp/gencert && COSIGN_PASSWORD="$passwd" cosign import-key-pair --key key.pem

COSIGN_PASSWORD="$passwd" cosign sign --timestamp-server-url "${TIMESTAMP_SERVER_URL}" \
	--timestamp-client-cacert ${TIMESTAMP_CLIENT_CACERT} --timestamp-client-cert ${TIMESTAMP_CLIENT_CERT} \
	--timestamp-client-key ${TIMESTAMP_CLIENT_KEY} --timestamp-server-name ${TIMESTAMP_SERVER_NAME}\
	--upload=true --tlog-upload=false --key import-cosign.key --certificate-chain cacert.pem --cert cert.pem $IMG

# key is now longer needed
rm -f key.pem import-cosign.*

echo "cosign verify:"
cosign verify --insecure-ignore-tlog --insecure-ignore-sct --check-claims=true \
	--certificate-identity-regexp 'xyz@nosuchprovider.com' --certificate-oidc-issuer-regexp '.*' \
	--certificate-chain cacert.pem $IMG
