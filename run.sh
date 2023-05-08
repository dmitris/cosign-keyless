#!/bin/bash
set -euo pipefail

## Requirements
# - cosign
# - crane
# - go

DOCKER_REGISTRY="docker.ouroath.com:4443"
DOCKER_USER="${USER}777"  ## CHANGE THIS to your docker repo!
BASE_IMAGE=scratch

IMG=${IMAGE_URI_DIGEST:-}
TIMESTAMP_SERVER_URL=${TIMESTAMP_SERVER_URL:="https://freetsa.org/tsr"}
if [[ "$#" -ge 1 ]]; then
	IMG=$1
elif [[ -z "${IMG}" ]]; then
	RAND_NAME=$(uuidgen | head -c 8 | tr 'A-Z' 'a-z')
	IMAGE_URI="$DOCKER_REGISTRY/$DOCKER_USER/${BASE_IMAGE}-${RAND_NAME}"
	echo "IMAGE_URI: $IMAGE_URI"
	docker build -t $IMAGE_URI .	
	docker tag $IMAGE_URI $IMAGE_URI:1.0
	docker push -a $IMAGE_URI
	SRC_DIGEST=$(docker manifest inspect --verbose $IMAGE_URI | jq -r '.Descriptor | .digest')
	IMG=$IMAGE_URI@$SRC_DIGEST
	echo "IMG: ${IMG}"
	docker inspect $IMG >& /dev/null || exit 42
fi


echo "IMG: $IMG, TIMESTAMP_SERVER_URL: $TIMESTAMP_SERVER_URL"

GOBIN=/tmp GOPROXY=https://proxy.golang.org,direct go install -v github.com/dmitris/gencert@latest

passwd=$(uuidgen | head -c 32 | tr 'A-Z' 'a-z')
# use gencert to generate CA, keys and certificates
echo "generate keys and certificates with gencert"
rm -f *.pem import-cosign.* && /tmp/gencert && COSIGN_PASSWORD="$passwd" cosign import-key-pair --key key.pem

# crane digest $IMG || true

echo "cosign sign:"
COSIGN_PASSWORD="$passwd" cosign sign --timestamp-server-url "${TIMESTAMP_SERVER_URL}" --upload=true --tlog-upload=false --key import-cosign.key --certificate-chain cacert.pem --cert cert.pem $IMG

# key is now longer needed
rm -f key.pem import-cosign.* 

# echo "cosign verify:"
# cosign verify --insecure-ignore-tlog --insecure-ignore-sct --check-claims=true \
# 	--certificate-identity-regexp 'xyz@nosuchprovider.com' --certificate-oidc-issuer-regexp '.*' \
# 	--certificate-chain cacert.pem $IMG

