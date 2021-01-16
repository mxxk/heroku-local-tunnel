FROM python:3.9-alpine as base
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

FROM base as build_python
RUN apk add build-base curl libffi-dev openssl-dev
WORKDIR /app
ENV POETRY_HOME=/opt/poetry
ENV PATH=${POETRY_HOME}/bin:${PATH}
RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python3 - -y
COPY pyproject.toml poetry.toml poetry.lock ./
RUN poetry install
RUN poetry export -f requirements.txt -o requirements.txt
RUN pip install -r requirements.txt --root ./python-deps

# NOTE: It should be possible to install Rustup on base Alpine Linux image and
# compile Tunnelto server, but the resulting executable segfaults when the
# client is run with `tunnelto --key SECRET_KEY`, which seems like a bug. Use
# separate image for static build instead.
FROM clux/muslrust:stable as build_rust
WORKDIR /app
RUN git clone --depth 1 --branch 0.1.12 https://github.com/agrinman/tunnelto.git .
RUN cargo build --bin tunnelto_server --release
# Place `tunnelto_server` in consistent location regardless of release of debug build.
RUN find target -name tunnelto_server -exec cp {} target \;

FROM base
RUN apk add --no-cache openssl haproxy libgcc
RUN wget -qO- https://github.com/just-containers/s6-overlay/releases/download/v1.21.8.0/s6-overlay-amd64.tar.gz | tar -xzC /
WORKDIR /app
COPY --from=build_python /app/python-deps /
COPY --from=build_rust /app/target/tunnelto_server ./
COPY haproxy.cfg renew-certificate.py ./
COPY services.d /etc/services.d/
ENV S6_KEEP_ENV=1
CMD ["/init"]
