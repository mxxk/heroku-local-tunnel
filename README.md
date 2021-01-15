# Heroku Localhost Tunnel

Provides a way to expose localhost services on publicly-reachable domains, using Heroku and [Tunnelto](https://github.com/agrinman/tunnelto).

## Components

The provided Dockerfile creates an image meant to run on Heroku which has the following components:

- **Tunnelto server.** Creates/removes localhost tunnels, routes tunnel traffic, communicates with remote Tunnelto client.
- **HAProxy.** Routes incoming traffic between the Tunnelto server control port (i.e. creating a tunnel) and the tunnel port (i.e. incoming tunnel traffic meant to go to localhost).
- **SSL certificate renewal script.** (Optional) When executed, runs [Certbot](https://certbot.eff.org/) in conjunction with [certbot-dns-cloudflare](https://certbot-dns-cloudflare.readthedocs.io/) and updates the Heroku application's SSL certificate. Normally, [Heroku ACM](https://devcenter.heroku.com/articles/automated-certificate-management) takes care of automatic certificate renewal, but cannot handle wildcard certificates, needed to support tunnels routed by subdomain.

## Setup

### Requirements

- Heroku application using paid dyno (for SSL support) or free dyno (no SSL support)
    - While Heroku does support SSL for free dynos, SSL for custom subdomains is not included, hence the limitation.
- Cloudflare-hosted custom domain (for SSL support)
- TODO: Document AWS account in US-East-1
- Tunnelto client (for running the tunnel)

### Instructions

1. Create a new Heroku application (or repurpose an existing one)

1. Point your custom domain of choice to it, as well as a wildcard subdomain of it. For example, if `my-tunnel.dev` is your custom domain, both `my-tunnel.dev` and `*.my-tunnel.dev` need to point to the Heroku application. See [Custom Domain Names for Apps](https://devcenter.heroku.com/articles/custom-domains) for more information.
    - Note: It is possible to have multiple custom domains, as long as each custom domain has a corresponding `*.{custom-domain}` wildcard subdomain also pointing to the Heroku application.

1. If your Heroku application is set to use a non-`container` stack, change it to use the `container` stack as this is a Docker application. (https://devcenter.heroku.com/articles/stack#migrating-to-a-new-stack)

1. Set the following [config vars](https://devcenter.heroku.com/articles/config-vars) on the Heroku application:
    - `TUNNELTO_CTRL_PORT`: `5000`
    - `TUNNELTO_TUNNEL_PORT`: `8080` (or another port as long as it is different from Heroku's `PORT` or `TUNNELTO_CTRL_PORT`)
    - `TUNNELTO_ALLOWED_HOSTS`: A comma-separated list of custom domains the application is reachable at (excluding wildcard domains, so if `my-tunnel.dev` and `my-tunnel-2.dev` are two custom domains, the variable is set to `my-tunnel.dev,my-tunnel-2.dev`)
    - `TUNNELTO_AWS_ACCESS_KEY_ID`: TODO
    - `TUNNELTO_AWS_SECRET_ACCESS_KEY`: TODO
    - `CERTBOT_EMAIL`: (For SSL support only) TODO
    - `CERTBOT_CLOUDFLARE_TOKEN`: (For SSL support only) TODO
    - `X_HEROKU_CLIENT_SECRET`: (For SSL support only) TODO
    - `X_HEROKU_REFRESH_TOKEN`: (For SSL support only) TODO

1. Deploy this repository to Heroku, either via Git or by building the Docker container locally and then deploying manually per instructions in https://devcenter.heroku.com/articles/container-registry-and-runtime.

1. To provision SSL certificates for the first time, run `heroku run -a {app-name-or-id} ./renew-certificate.py`

1. To make SSL certificate renewal a daily Heroku job:
    - Provision the [Heroku scheduler add-on](https://devcenter.heroku.com/articles/scheduler)
    - Create a daily job which runs `./renew-certificate.py`
    - Note: If the job is set to run more frequently (e.g. hourly or every 10 minutes), Certbot will start failing to generate certificates due to [Certbot rate limits](https://letsencrypt.org/docs/rate-limits/)

1. Install the Tunnelto client per instructions in [Tunnelto](https://github.com/agrinman/tunnelto) and test out the tunnel:

    ```
    # If using SSL
    CTRL_HOST=my-tunnel.dev tunnelto

    # If not using SSL
    CTRL_HOST=my-tunnel.dev CTRL_PORT=80 CTRL_TLS_OFF=1 tunnelto
    ```
