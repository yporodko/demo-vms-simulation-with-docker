FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

# Install Python3, SSH server, and utilities
RUN apt-get update && \
    apt-get install -y \
    python3 \
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

EXPOSE 80 22

ENTRYPOINT ["/entrypoint.sh"]
