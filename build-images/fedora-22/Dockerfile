FROM alanfranz/fwd-fedora-22:latest
MAINTAINER Alan Franzoni <username@franzoni.eu>
RUN dnf clean metadata && dnf -y update
RUN dnf -y install ruby ruby-devel rsync which
RUN gem install rake bundler
