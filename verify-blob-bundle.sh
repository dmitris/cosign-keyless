#!/bin/bash
set -euo pipefail

## Requirements
# - cosign
# - crane
# - go

COSIGN=${COSIGN:="cosign"}
TIMESTAMP_SERVER_URL=${TIMESTAMP_SERVER_URL:="https://freetsa.org/tsr"}
TIMESTAMP_CERTCHAIN=${TIMESTAMP_CERTCHAIN:=""}
if [[ "${TIMESTAMP_SERVER_URL}" == "https://freetsa.org/tsr" ]]; then
	# download the TSA and TSA CA certificates and create the certificate chain file
	rm -fr tsa.crt cacert.pem tsa-certchain.pem
	curl -sSfL https://freetsa.org/files/tsa.crt -o tsa.crt
	curl -sSfL https://freetsa.org/files/cacert.pem -o cacert.pem
	cat cacert.pem tsa.crt > tsa-certchain.pem
	TIMESTAMP_CERTCHAIN="tsa-certchain.pem"
fi
if [[ -z "${TIMESTAMP_CERTCHAIN}" ]]; then
	echo "TIMESTAMP_CERTCHAIN is not set and TIMESTAMP_SERVER_URL ${TIMESTAMP_SERVER_URL} is not default (https://freetsa.org/tsr)"
	exit 1
fi

echo "TIMESTAMP_SERVER_URL: $TIMESTAMP_SERVER_URL, TIMESTAMP_CERTCHAIN: $TIMESTAMP_CERTCHAIN"

GOBIN=/tmp GOPROXY=https://proxy.golang.org,direct go install -v github.com/dmitris/gencert@latest

rm -f ca-key.pem key.pem
# use gencert to generate CA, keys and certificates
echo "generate keys and certificates with gencert"

passwd=$(uuidgen | head -c 32 | tr 'A-Z' 'a-z')
# rm -f import-cosign.* && \
/tmp/gencert && COSIGN_PASSWORD="$passwd" cosign import-key-pair --key key.pem

SIG_TIMESTAMP_FILE="sig-timestamp.txt"
COSIGN_BUNDLE_FILE="cosign.bundle"
echo "${COSIGN} sign-blob:"
COSIGN_PASSWORD="$passwd" ${COSIGN} sign-blob --verbose \
	--timestamp-server-url "${TIMESTAMP_SERVER_URL}" \
    --rfc3161-timestamp ${SIG_TIMESTAMP_FILE} --tlog-upload=false --key import-cosign.key \
	--bundle ${COSIGN_BUNDLE_FILE} README.md

# key is now longer needed
rm -f key.pem import-cosign.*

echo "${COSIGN} verify-blob (with --certificate-chain):"
${COSIGN} verify-blob --private-infrastructure --insecure-ignore-sct \
	--certificate-identity-regexp 'xyz@nosuchprovider.com' --certificate-oidc-issuer-regexp '.*' \
	--certificate cert.pem --certificate-chain cacert.pem \
	--rfc3161-timestamp ${SIG_TIMESTAMP_FILE} --timestamp-certificate-chain=$TIMESTAMP_CERTCHAIN \
	--bundle ${COSIGN_BUNDLE_FILE} README.md
echo "${COSIGN} verify-blob (with --ca-roots):"
${COSIGN} verify-blob --private-infrastructure --insecure-ignore-sct \
	--certificate-identity-regexp 'xyz@nosuchprovider.com' --certificate-oidc-issuer-regexp '.*' \
	--certificate cert.pem --ca-roots cacert.pem \
	--rfc3161-timestamp ${SIG_TIMESTAMP_FILE} --timestamp-certificate-chain=$TIMESTAMP_CERTCHAIN \
	--bundle ${COSIGN_BUNDLE_FILE} README.md

# cleanup
rm -f tsa-certchain.pem tsa.crt
