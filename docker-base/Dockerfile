FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages that all VMs have
RUN apt-get update && \
    apt-get install -y \
    openssh-server \
    sudo \
    vim \
    net-tools \
    iputils-ping \
    curl \
    wget \
    ca-certificates \
    python3 \
    python3-apt \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure SSH
RUN mkdir -p /var/run/sshd

# Create testuser with sudo access (matches VM setup)
RUN useradd -m -s /bin/bash testuser && \
    echo 'testuser:testpass' | chpasswd && \
    usermod -aG sudo testuser

# Allow password authentication and root login
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Set root password for SSH access (same as testuser for consistency)
RUN echo 'root:testpass' | chpasswd

# Allow passwordless sudo for testuser
RUN echo 'testuser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Copy SSH public key for root user (matches VM setup)
# This key should exist at ~/.ssh/redi_test_key.pub on the host
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
COPY redi_test_key.pub /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

# Disable password authentication (key-based only, like VMs)
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

EXPOSE 22

# Start SSH and keep container running
# Note: For testing, services installed by Ansible need to be started manually
# after configuration (systemd doesn't work well in basic Docker containers)
CMD ["/usr/sbin/sshd", "-D"]
