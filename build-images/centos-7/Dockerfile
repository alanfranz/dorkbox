FROM alanfranz/fwd-centos-7:latest
MAINTAINER Alan Franzoni <username@franzoni.eu>
RUN yum clean metadata && yum -y update
RUN yum -y install ruby ruby-devel rsync
RUN gem install rake bundler
