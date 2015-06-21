FROM alanfranz/fwd-fedora-rawhide:latest
MAINTAINER Alan Franzoni <username@franzoni.eu>
RUN yum clean metadata && yum -y update
RUN dnf -y install ruby ruby-devel rsync which
RUN gem install rake bundler
