#!/bin/bash

# script to fetch JWT token for Docker Registry API access.
# Usage: ./apicreds [<image>], ex. ./apicreds dsavints777/deleteme-test04
#
# References:
# https://git.ouryahoo.com/pages/Docker/Registry-Guide/#api-for-docker-registry
# (NB) https://git.ouryahoo.com/pages/Docker/Registry-Guide/#helper-function-if-using-athens-user-cert

set -euo pipefail

# remember to run 'athenz-user-cert' unless done in the last hour!
IMAGE="dsavints777/deleteme-test05" # CHANGE THIS! used as default if no $1
SCOPE="pull" # or "pull,push" if needed
# declare ROLE
ROLE="dummy_role_pusher" # optional - normally not needed!
UNAME=$(uname)
ACC='Accept: application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.docker.distribution.manifestv2+json'

if [[ $# -ge 1 ]]; then
	IMAGE=$1
fi

if [[ -z "${ROLE:-}" ]]; then
	zts-roletoken -domain cd.docker.registry -svc-cert-file ~/.athenz/cert -svc-key-file ~/.athenz/key -zts https://zts.athens.yahoo.com:4443/zts/v1 > roletoken.txt
else
	zts-roletoken -role ${ROLE} -domain cd.docker.registry -svc-cert-file ~/.athenz/cert -svc-key-file ~/.athenz/key -zts https://zts.athens.yahoo.com:4443/zts/v1 > roletoken.txt
fi	
rtkn=$(cat roletoken.txt)
if [[ "${UNAME}" = "Darwin" ]]; then
	rtkn64=$(echo -n "user.${USER}:$rtkn" | base64)
else
	rtkn64=$(echo -n "user.${USER}:$rtkn" | base64 --wrap 0)
fi
jwt=$(curl -fsL -H "Authorization: Basic $rtkn64" "https://docker.ouroath.com:4443/token?service=docker.ouroath.com&scope=repository:${IMAGE}:${SCOPE}" | jq -r .token)
echo $jwt
curl -H "Authorization: Bearer $jwt" https://docker.ouroath.com:4443/v2/$IMAGE/tags/list
echo ""
# fetch the manifest for the existing image:tag (tag=latest)
curl -H "${ACC}" -H "Authorization: Bearer $jwt" https://docker.ouroath.com:4443/v2/$IMAGE/manifests/latest
echo ""
# attempt to fetch the manifest for the existing image but bogus tag =nosuchref
curl -i -H "${ACC}" -H "Authorization: Bearer $jwt" https://docker.ouroath.com:4443/v2/$IMAGE/manifests/nosuchref
echo ""

# attempt to fetch the manifest for a non-existing image
curl -i -H "${ACC}" -H "Authorization: Bearer $jwt" https://docker.ouroath.com:4443/v2/dsavints777/nosuchimg/manifests/latest
echo ""
