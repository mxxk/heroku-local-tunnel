FROM python:3.9-alpine as base
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

FROM base as build_base
RUN apk update && apk add curl build-base openssl-dev
WORKDIR /app

FROM build_base as build_python
RUN apk add libffi-dev
ENV POETRY_HOME=/opt/poetry
ENV PATH=${POETRY_HOME}/bin:${PATH}
RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python3 - -y
# NOTE: In order for the Python venv build on this stage to work on the final stage, the path must be consistent.
COPY pyproject.toml poetry.toml poetry.lock ./
RUN poetry install

FROM build_base as build_rust
RUN apk add git libgcc
ENV CARGO_HOME=/opt/cargo
ENV PATH=${CARGO_HOME}/bin:${PATH}
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
RUN git clone --depth 1 --branch 0.1.12 https://github.com/agrinman/tunnelto.git .
RUN cargo build --bin tunnelto_server --release

FROM base
RUN apk add --no-cache openssl tini haproxy libgcc python3
WORKDIR /app
COPY --from=build_python /app/.venv ./
COPY --from=build_rust /app/target/release/tunnelto_server ./
COPY haproxy.cfg docker-entrypoint.py ./
# Use Tini explicitly since Heroku does not provide a way to do `docker run --init`.
# Make Tini be a subreaper since Heroku does not run it as PID 1.
ENTRYPOINT ["tini", "-s", "--"]
CMD ["./docker-entrypoint.py"]
