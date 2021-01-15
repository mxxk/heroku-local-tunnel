#!/usr/bin/env python3

import json
import os
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import urllib.error
import urllib.parse
import urllib.request


CERTS_DIR = './etc'
ENV = SimpleNamespace(**{
    name: os.environ[name]
    for name in [
        'TUNNELTO_ALLOWED_HOSTS',
        'CERTBOT_CLOUDFLARE_TOKEN',
        'CERTBOT_EMAIL',
        # Prefixed with `X_` since `HEROKU_` prefix is reserved
        'X_HEROKU_REFRESH_TOKEN',
        'X_HEROKU_CLIENT_SECRET',
        # These variables are made available via
        # https://devcenter.heroku.com/articles/dyno-metadata
        'HEROKU_APP_ID',
    ]
})
DOMAINS = ENV.TUNNELTO_ALLOWED_HOSTS.split(',')


def run_certbot():
    wildcard_domains = ','.join(
        name
        for domain in DOMAINS
        for name in (domain, f'*.{domain}')
    )
    cloudflare_credentials = './cloudflare_credentials.ini'
    with open(
        os.open(cloudflare_credentials, os.O_CREAT | os.O_WRONLY, 0o600),
        'w',
    ) as f:
        f.write(f'dns_cloudflare_api_token = {ENV.CERTBOT_CLOUDFLARE_TOKEN}')
    subprocess.run(
        [
            'certbot',
            'certonly',
            '--work-dir', './var/lib',
            '--config-dir', CERTS_DIR,
            '--logs-dir', './var/logs',
            '--dns-cloudflare',
            '--dns-cloudflare-credentials', cloudflare_credentials,
            '--email', ENV.CERTBOT_EMAIL,
            '--no-eff-email',
            '--non-interactive',
            '--agree-tos',
            '--domain', wildcard_domains,
        ],
        check=True,
    )


def update_heroku_cert():
    # Get access token
    # TODO: Get SNI endpoint, and decide whether PATCH or POST is needed
    data = {
        'grant_type': 'refresh_token',
        'refresh_token': ENV.X_HEROKU_REFRESH_TOKEN,
        'client_secret': ENV.X_HEROKU_CLIENT_SECRET,
    }
    with urllib.request.urlopen(
        'https://id.heroku.com/oauth/token',
        data=urllib.parse.urlencode(data).encode(),
    ) as response:
        headers = {
            'Accept': 'application/vnd.heroku+json; version=3',
            'Authorization': 'Bearer ' + json.load(response)['access_token'],
            'Content-Type': 'application/json',
        }
    sni_url = (
        f'https://api.heroku.com/apps/{ENV.HEROKU_APP_ID}/sni-endpoints'
    )
    with urllib.request.urlopen(
        urllib.request.Request(sni_url, headers=headers),
    ) as response:
        sni_endpoints = json.load(response)
        sni_endpoint_id = None if not sni_endpoints else sni_endpoints[0]['id']
    cert_dir = os.path.join(CERTS_DIR, 'live', DOMAINS[0])
    with (
        open(os.path.join(cert_dir, 'fullchain.pem')) as fullchain,
        open(os.path.join(cert_dir, 'privkey.pem')) as privkey,
    ):
        data = {
            'certificate_chain': fullchain.read(),
            'private_key': privkey.read(),
        }
    sni_update_url, sni_update_method = (
        (f'{sni_url}/{sni_endpoint_id}', 'PATCH')
        if sni_endpoint_id else
        (sni_url, 'POST')
    )
    with urllib.request.urlopen(urllib.request.Request(
        sni_update_url,
        headers=headers,
        method=sni_update_method,
        data=json.dumps(data).encode(),
    )) as response:
        print('SSL certificate successfully installed')


def main():
    with tempfile.TemporaryDirectory() as temp_dir:
        os.chdir(temp_dir)
        run_certbot()
        try:
            update_heroku_cert()
        except urllib.error.HTTPError as e:
            print(e.read().decode())
            raise e


if __name__ == '__main__':
    main()
