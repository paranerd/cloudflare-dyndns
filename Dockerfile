FROM alpine:latest

RUN apt-get update && apt-get install -y curl

COPY cloudflare_dyndns.sh /

CMD ["/bin/bash", "/cloudflare_dyndns.sh"]
