FROM andrius/asterisk:latest

USER root

# Create a simple entrypoint that copies configs then runs Asterisk
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 5060/udp 5060/tcp 10000-20000/udp

ENTRYPOINT ["/entrypoint.sh"]
