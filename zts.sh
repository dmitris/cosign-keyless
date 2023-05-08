#!/bin/bash
rm -fr ./service_cert.pem
zts-svccert -domain home.dsavints -service  test0 -private-key ~/backup/misc/test0.key -key-version 0 -zts https://zts.athens.yahoo.com:4443/zts/v1 -dns-domain zts.yahoo.cloud -hdr Yahoo-Principal-Auth -cert-file ./service_cert.pem
zts-roletoken -domain cd.docker.registry -svc-cert-file ~/.athenz/cert -svc-key-file ~/.athenz/key -zts https://zts.athens.yahoo.com:4443/zts/v1 > roletoken.txt
docker login -u home.dsavints.test0 -p $(cat roletoken.txt) docker.ouroath.com:4443
