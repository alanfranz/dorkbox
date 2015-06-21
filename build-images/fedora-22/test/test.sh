#!/bin/bash
set -ex
dnf install -y  /build/*.rpm
git config --global user.email "john@example.com"
git config --global user.name "John Doe"
/opt/dorkbox/bin/test --force
