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
# This command pulls the latest puppet config, validates
# it and applies it.

ROOTDIR=$(git rev-parse --show-toplevel)

cd "$ROOTDIR"

git pull
git submodule update --recursive --init
bin/validate.sh
if [ "$?" == "0" ]; then
    puppet apply "${ROOTDIR}/manifests/site.pp"
else
    echo "Validation failed, not applying."
fi
