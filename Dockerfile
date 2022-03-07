FROM alpine:latest

RUN apk add --no-cache bash curl
RUN apk add --no-cache --upgrade grep

COPY cloudflare_dyndns.sh /

CMD ["/bin/bash", "/cloudflare_dyndns.sh"]
