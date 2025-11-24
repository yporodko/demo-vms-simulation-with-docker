FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

# Copy provisioning scripts
COPY ../provisioning/common/base-install.sh /tmp/base-install.sh
COPY ../provisioning/common/base-configure.sh /tmp/base-configure.sh
COPY ../provisioning/maria-primary/install.sh /tmp/maria-install.sh
COPY ../provisioning/maria-primary/configure.sh /tmp/maria-configure.sh

# Copy configuration files to temp location for configure script
COPY config/my.cnf /tmp/maria-config/my.cnf
COPY init/voip_db.sql /tmp/maria-init/voip_db.sql

# Run installation scripts
RUN chmod +x /tmp/*.sh && \
    /tmp/base-install.sh && \
    /tmp/base-configure.sh && \
    /tmp/maria-install.sh && \
    rm -f /tmp/*.sh

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3306 22

ENTRYPOINT ["/entrypoint.sh"]
