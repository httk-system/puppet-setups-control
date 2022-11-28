#!/bin/bash
#
# This file is part of puppet-setups-control:
#   https://github.com/httk-system/puppet-setups-control
#
# (c) Rickard Armiento (2022)
#
# Use of this source code is governed by an MIT-style
# license that can be found in the LICENSE file or at
# https://opensource.org/licenses/MIT.
#
# This script sets the system id, either to the provided string,
# or if left blank, to a name derived from the hardware address
# of the main network interface.

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

if [ -n "$1" ]; then
    SYSTEM_ID="$1"
else
    MAIN_IP=$(hostname -I | head -n 1 | tr -d ' ')
    MAIN_IF=$(ip -br -4 a sh | grep "$MAIN_IP" | awk '{print $1}')
    MAIN_MAC=$(cat "/sys/class/net/$MAIN_IF/address" | tr -d ':')
    SYSTEM_ID="mac-$MAIN_MAC"
fi

if [ -z "SYSTEM_ID" ]; then
	echo "Could not derive a system_id for the system. You need to supply a name on the command line. Aborting."
	exit 1
fi

echo "SYSTEM ID: $SYSTEM_ID"
mkdir -p /etc/facter/facts.d/
echo "system_id=$SYSTEM_ID" > /etc/facter/facts.d/system_id.txt
