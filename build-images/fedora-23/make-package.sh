#!/bin/bash
set -ex
[ -n "$1" ]
[ -n "$2" ]
mkdir -p /opt
cd /application
rsync -av --filter=':- .gitignore' --exclude='.git' . /opt/dorkbox
cd /opt/dorkbox
rake clobber create_bundler_binstubs PRODUCTION=yes RUBY_EXEC=$(which ruby)
install -D -m 0755 wrapper/dorkbox /launch/bin/dorkbox
cd /build
fpm -t rpm -s dir -n dorkbox --version "$1" --iteration "$2" --depends ruby --depends git --depends cronie --depends rubygem-minitest -C / opt /launch/bin=/usr
chmod 666 *
