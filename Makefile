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
tag: IMAGE_ID := $(shell docker-compose images -q "$(SERVICE)")
tag: build
	$(if \
		$(filter 1,$(words $(IMAGE_ID))), \
		, \
		$(error Expected only one image ID instead of $(IMAGE_ID)) \
	)
	docker tag \
		"$$(docker-compose images -q "$(SERVICE)")" \
		"registry.heroku.com/$(HEROKU_APP)/$(SERVICE)"

.PHONY: build
build:
	docker-compose build
# Needed to enable `docker-compose images` to show the newly built image ID
	docker-compose up --no-start
