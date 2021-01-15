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
    subprocess.Popen(['./tunnelto_server'], env={
        'RUST_LOG': 'tunnelto_server=debug',
        'RUST_BACKTRACE': '1',
        'PORT': os.environ['TUNNELTO_TUNNEL_PORT'],
        'ALLOWED_HOSTS': os.environ['TUNNELTO_ALLOWED_HOSTS'],
        'AWS_ACCESS_KEY_ID': os.environ['TUNNELTO_AWS_ACCESS_KEY_ID'],
        'AWS_SECRET_ACCESS_KEY': os.environ['TUNNELTO_AWS_SECRET_ACCESS_KEY'],
    })
    # Wait for first process to exit, then exit the entire program.
    os.wait()


if __name__ == '__main__':
    main()
