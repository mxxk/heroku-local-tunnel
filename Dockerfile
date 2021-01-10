FROM alpine as build_base
RUN apk update && apk add build-base openssl-dev

FROM build_base as build_python
RUN apk add python3-dev libffi-dev
RUN python3 -m venv /build/venv
ENV PATH=/build/venv/bin:${PATH}
RUN pip3 install certbot

FROM build_base as build_rust
RUN apk add curl git libgcc
ENV CARGO_HOME=/cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
WORKDIR /build/tunnelto
RUN git clone --depth 1 --branch 0.1.12 https://github.com/agrinman/tunnelto.git .
ENV PATH=${CARGO_HOME}/bin:${PATH}
RUN cargo build --bin tunnelto_server --release

FROM alpine
RUN apk add --no-cache bash tini haproxy libgcc python3
WORKDIR /app
COPY --from=build_python /build/venv ./venv/
COPY --from=build_rust /build/tunnelto/target/release/tunnelto_server ./
COPY ./haproxy.cfg ./docker-entrypoint.py ./
# Use Tini explicitly since Heroku does not provide a way to do `docker run --init`
ENTRYPOINT ["tini", "--"]
ENV PATH=/app/venv/bin:${PATH}
CMD ["./docker-entrypoint.sh"]
