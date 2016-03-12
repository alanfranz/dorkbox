#!/bin/bash
set -ex
dpkg -i /build/*.deb || /bin/true
apt-get -y -f install
git config --global user.email "john@example.com"
git config --global user.name "John Doe"
/opt/dorkbox/bin/test --force
