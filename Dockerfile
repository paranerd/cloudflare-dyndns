FROM alpine:latest

RUN apk add --no-cache curl

COPY cloudflare_dyndns.sh /

CMD ["/bin/bash", "/cloudflare_dyndns.sh"]
