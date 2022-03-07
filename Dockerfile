FROM alpine:latest

RUN apk add --no-cache bash curl

COPY cloudflare_dyndns.sh /

CMD ["/bin/bash", "/cloudflare_dyndns.sh"]
