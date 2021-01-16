SHELL := /usr/bin/env bash
SERVICE := web

ifeq ($(HEROKU_APP),)
$(error HEROKU_APP is not set)
endif

.PHONY: release
release: push
	heroku container:release -a "$(HEROKU_APP)" "$(SERVICE)"

.PHONY: push
push: tag
	docker login registry.heroku.com \
		-u _ \
		--password-stdin <<<"$$(heroku auth:token)"
	docker push "registry.heroku.com/$(HEROKU_APP)/$(SERVICE)"

.PHONY: tag
tag: build
	docker tag \
		"$$(docker-compose images -q "$(SERVICE)")" \
		"registry.heroku.com/$(HEROKU_APP)/$(SERVICE)"

.PHONY: build
build:
	docker-compose build
# Needed to enable `docker-compose images` to show the newly built image ID
	docker-compose up --no-start
