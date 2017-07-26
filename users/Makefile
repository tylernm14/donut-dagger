container_name := users
container_registry := tylernm14
container_release := mine

.PHONY: build tag push

build:
	docker build \
		-t $(container_name):$(container_release) .

tag: build
	docker tag $(container_name):$(container_release) $(container_registry)/$(container_name):$(container_release)

push: tag
	docker push $(container_registry)/$(container_name):$(container_release)
