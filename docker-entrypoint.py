#!/usr/bin/env python3

import os
import subprocess


def main():
    os.chdir(os.path.dirname(__file__) or '.')
    subprocess.Popen(['haproxy', '-f', './haproxy.cfg'], env={
        name: os.environ[name]
        for name in [
            'PATH',
            'PORT',
            'TUNNELTO_ALLOWED_HOSTS',
            'TUNNELTO_CTRL_PORT',
            'TUNNELTO_TUNNEL_PORT',
        ]
    }),
    tunnelto_env = {
        'RUST_LOG': 'tunnelto_server=debug',
        'RUST_BACKTRACE': '1',
        'PORT': os.environ['TUNNELTO_TUNNEL_PORT'],
        'ALLOWED_HOSTS': os.environ['TUNNELTO_ALLOWED_HOSTS'],
        # TODO: DECIDE
        # 'ALLOW_UNKNOWN_CLIENTS': '1',
    }
    tunnelto_secret_key = os.environ.get('TUNNELTO_SECRET_KEY')
    if tunnelto_secret_key:
        tunnelto_env['SECRET_KEY'] = tunnelto_secret_key
    subprocess.Popen(['./tunnelto_server'], env=tunnelto_env)
    # Wait for first process to exit, then exit the entire program.
    os.wait()


if __name__ == '__main__':
    main()
