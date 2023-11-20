#!/bin/bash
set -euo pipefail

## Requirements
# - cosign
# - crane
# - go

IMG=${IMAGE_URI_DIGEST:-}
TIMESTAMP_SERVER_URL=${TIMESTAMP_SERVER_URL:="https://freetsa.org/tsr"}
TIMESTAMP_CERTCHAIN=${TIMESTAMP_CERTCHAIN:=""}
if [[ "${TIMESTAMP_SERVER_URL}" == "https://freetsa.org/tsr" ]]; then
	# download the TSA and TSA CA certificates and create the certificate chain file
	rm -fr tsa.crt cacert.pem tsa-certchain.pem
	curl -sSfL https://freetsa.org/files/tsa.crt -o tsa.crt
	curl -sSfL https://freetsa.org/files/cacert.pem -o cacert.pem
	cat cacert.pem tsa.crt > tsa-certchain.pem
	echo "(PWD: $PWD) tsa-certchain.pem:"
	cat tsa-certchain.pem
	TIMESTAMP_CERTCHAIN="tsa-certchain.pem"
fi
if [[ -z "${TIMESTAMP_CERTCHAIN}" ]]; then
	echo "TIMESTAMP_CERTCHAIN is not set and TIMESTAMP_SERVER_URL ${TIMESTAMP_SERVER_URL} is not default (https://freetsa.org/tsr)"
	exit 1
fi
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

echo "IMG (IMAGE_URI_DIGEST): $IMG, TIMESTAMP_SERVER_URL: $TIMESTAMP_SERVER_URL, TIMESTAMP_CERTCHAIN: $TIMESTAMP_CERTCHAIN"

GOBIN=/tmp GOPROXY=https://proxy.golang.org,direct go install -v github.com/dmitris/gencert@latest

rm -f ca-key.pem key.pem
# use gencert to generate CA, keys and certificates
echo "generate keys and certificates with gencert"

passwd=$(uuidgen | head -c 32 | tr 'A-Z' 'a-z')
rm -f import-cosign.* && /tmp/gencert && COSIGN_PASSWORD="$passwd" cosign import-key-pair --key key.pem

echo "cosign sign:"
COSIGN_PASSWORD="$passwd" cosign sign --timestamp-server-url "${TIMESTAMP_SERVER_URL}" --upload=true --tlog-upload=false --key import-cosign.key --certificate-chain cacert.pem --cert cert.pem $IMG

# key is now longer needed
rm -f key.pem import-cosign.* 

echo "cosign verify:"
cosign verify --private-infrastructure --insecure-ignore-sct --check-claims=true \
	--certificate-identity-regexp 'xyz@nosuchprovider.com' --certificate-oidc-issuer-regexp '.*' \
	--certificate-chain cacert.pem --timestamp-certificate-chain=$TIMESTAMP_CERTCHAIN $IMG

# cleanup
rm -f tsa-certchain.pem tsa.crt
