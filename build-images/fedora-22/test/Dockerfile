FROM fedora:22
MAINTAINER Alan Franzoni <username@franzoni.eu>
RUN echo "timeout=300" >> /etc/dnf/dnf.conf ; sed -i.old -e 's/#baseurl=/baseurl=/g' -e 's/metalink=/#metalink=/g' /etc/yum.repos.d/*.repo ; dnf clean metadata ; dnf -y --noplugins update
