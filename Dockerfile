FROM bash:latest

COPY cloudflare_dyndns.sh /

CMD ["bash", "/cloudflare_dyndns.sh"]