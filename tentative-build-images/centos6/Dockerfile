FROM alanfranz/fwd-centos-6:latest
MAINTAINER Alan Franzoni <username@franzoni.eu>
RUN yum clean metadata && yum -y update
RUN yum install -y centos-release-SCL
RUN yum -y install ruby193 ruby193-scldevel ruby193-ruby-devel rsync which
RUN source /opt/rh/ruby193/enable ; gem install rake bundler
