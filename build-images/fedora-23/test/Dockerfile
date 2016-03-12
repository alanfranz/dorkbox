FROM fedora:23
MAINTAINER Alan Franzoni <username@franzoni.eu>
RUN sed -i.old -e 's/#baseurl=/baseurl=/g' -e 's/metalink=/#metalink=/g' /etc/yum.repos.d/*.repo
RUN yum clean metadata ; yum -y update
RUN echo "timeout=300" >> /etc/dnf/dnf.conf
