# Cloudflare DynDNS Updater

This is a handy tool to update your Cloudflare managed DNS records to your current public IP.

## Prerequisites

### Environment

If you're using this with Docker you obviously need to have Docker installed, otherwise you only need to install `curl`.

### Credentials

For the script to work you need a **Cloudflare API Token** or a Global API Key ([not recommended](https://developers.cloudflare.com/api/keys)).

Check [this Cloudflare article](https://developers.cloudflare.com/api/tokens/create) on how to create an API Token.

### Identifiers

The script needs a **Record Name** as well as the **Zone ID** that you're trying to update.

The record name is simply the name of your A-Record (e.g. `example.com`, `sub.example.com` or `*.sub.example.com`).

You can find your Zone ID at the bottom right on the overview page of your domain in the Cloudflare Dashboard.

The `email` parameter is only required when using a Global API Key (again: not recommended). Otherwise it can be left blank.

## How to use

### Update config

Enter your details in the `cloudflare.ini`

Start a new section for each record name:

```
[example.com]
ZONE_ID=0987654321gfedcba
RECORD_NAME=example.com
AUTH_METHOD=token
API_KEY=1234567890abcdefg
EMAIL=yourmail@example.com
```

### Standalone

You can use the script as a standalone bash-script.

Simply call `cloudflare_dyndns.sh`.

### Docker

Running the following command should do the rest:

```bash
docker run --rm -v "/path/to/cloudflare.ini:/cloudflare.ini" paranerd/cloudflare-dyndns
```

I suggest setting up a cron job so you don't have to run it manually all the time.
