FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive
ENV POSTGRES_VERSION=9.6

# Add PostgreSQL repository for version 9.6
RUN apt-get update && \
    apt-get install -y wget gnupg2 lsb-release && \
    echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Install PostgreSQL 9.6, SSH server, and utilities
RUN apt-get update && \
    apt-get install -y \
    postgresql-9.6 \
    postgresql-client-9.6 \
    openssh-server \
    sudo \
    vim \
    net-tools \
    iputils-ping \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create SSH directory
RUN mkdir /var/run/sshd

# Create user for SSH access
RUN useradd -m -s /bin/bash testuser && \
    echo 'testuser:testpass' | chpasswd && \
    usermod -aG sudo testuser

# Allow password authentication
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 5432 22

ENTRYPOINT ["/entrypoint.sh"]
