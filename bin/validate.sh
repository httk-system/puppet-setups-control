#!/bin/bash
#
# This file is part of puppet-setups:
#   https://github.com/httk-system/puppet-setups
#
# (c) Rickard Armiento (2022)
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# Validate that the control repository is in a good state

set -e

ROOTDIR=$(git rev-parse --show-toplevel)

cd "$ROOTDIR"

echo "Validating gpg trusted signatures"
if [ -z "$TRUSTED_SHA256" ]; then
   TRUSTED_SHA256=$(dig -t txt trusted.armiento.net +short)
   TRUSTED_SHA256="${TRUSTED_SHA256//\"}"
fi
if sha256sum -c <<<"$TRUSTED_SHA256 security/trusted_keys.asc"; then
    echo "trusted_keys.asc: OK"
else
    echo "trusted_keys.asc: FAILED"
    exit 1
fi

echo "Validating git repo"
if git fsck --strict --no-dangling --full && git submodule foreach --recursive git fsck --no-dangling --full; then
    echo "git repo: OK"
else
    echo "git repo: FAILED"
    exit 1
fi

rm -rf ~/.gnupg-puppet
mkdir -p ~/.gnupg-puppet
chmod 700 ~/.gnupg-puppet
export GNUPGHOME=~/.gnupg-puppet
cat > ~/.gnupg-puppet/gpg.conf <<EOF
no-default-keyring
trust-model always
EOF
gpg --import "$ROOTDIR/security/trusted_keys.asc"

echo "Validating git repo signature"
if git verify-commit HEAD; then
    echo "git signature: OK"
else
    echo "git signature: FAILED"
    exit 1
fi
