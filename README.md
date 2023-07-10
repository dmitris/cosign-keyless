# cosign-keyless
`run.sh` is a test script that generates CA and certificate and
runs `cosign sign` and `cosign verify` with the ["keyless verification"](https://docs.sigstore.dev/cosign/keyless/).

## Prerequisites
- Go - https://go.dev/dl or `brew install golang`
- `cosign` - https://github.com/sigstore/cosign
- `crane` (to publish a test image to ttl.sh) - https://github.com/michaelsauter/crane, `brew install crane`

## sigstore/cosign Pull Request 2845
This script was done as part of testing for https://github.com/sigstore/cosign/pull/2845 "verify command: support keyless verification using only a provided certificate chain with non-fulcio roots".
It is expected to fail the verification with the trunk version of sigstore. If you want to try this
before the PR is merged, please check out the PR branch https://github.com/dmitris/cosign/tree/keyless-without-fulcio.

## Usage
```bash
./run.sh
```

If you have an image to sign/verify, you can pass it as the first parameter to `./run.sh`
or through the `IMAGE_URI_DIGEST` environment variable:
```bash
./run.sh ttl.sh/2291f828@sha256:b5d6fe0712636ceb7430189de28819e195e8966372edfc2d9409d79402a0dc16
```

## sigstore/cosign Pull Request 3052 - mTLS to TSA
To test `cosign` support for an mTLS connection to the timestamp server ([sigstore/cosign#3052](https://github.com/sigstore/cosign/pull/3052)), use `./run-tls.sh` and
see the "Sample run" example on the top of that script for the mTLS-related parameters.
