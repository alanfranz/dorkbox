FROM alanfranz/fwd-debian-jessie:latest
MAINTAINER Alan Franzoni <username@franzoni.eu>
RUN apt-get -y update
RUN apt-get -y dist-upgrade
RUN apt-get -y install ruby rubygems-integration rsync
RUN gem install rake bundler
