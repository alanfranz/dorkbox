#!/bin/bash
set -ex
[ -n "$1" ]
mkdir -p /opt
cd /application
rsync -av --filter=':- .gitignore' --exclude='.git' . /opt/dorkbox
cd /opt/dorkbox

cat <<EOM > ruby1.9.3
#!/bin/bash
set -e
source /opt/rh/ruby193/enable
export PATH=/opt/rh/ruby193/root/usr/local/bin\${PATH:+:\${PATH}}
/opt/rh/ruby193/root/usr/bin/ruby "\$@"
EOM
chmod +x ruby1.9.3

source /opt/rh/ruby193/enable
export PATH=/opt/rh/ruby193/root/usr/local/bin${PATH:+:${PATH}}
rake clobber create_bundler_binstubs PRODUCTION=yes RUBY_EXEC=/opt/dorkbox/ruby1.9.3
cd /
ln -s /opt/dorkbox/bin/dorkbox /usr/bin
cd /build
fpm -t rpm -s dir -n dorkbox --version "$1" --depends ruby193 --depends git --depends cronie --depends ruby193-rubygem-minitest -C / /opt/dorkbox /usr/bin/dorkbox
chmod 666 *
