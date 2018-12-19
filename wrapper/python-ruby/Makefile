container_name := timer-py-rb
container_registry := tylernm14
container_release := mine

.PHONY: build tag push

build:
	cd streamed_job; python setup.py sdist; cd ..
	docker build \
		-t $(container_name):$(container_release) -f Dockerfile .
build-no-cache:
	cd streamed_job; python setup.py sdist; cd ..
	docker build \
		-t $(container_name):$(container_release) -f Dockerfile --no-cache .

build-timer-no-cache:
	docker build \
		-t $(container_name):$(container-release) -f Dockerfile --no-cache .
tag: build
	cd streamed_job; python setup.py sdist; cd ..
	docker tag $(container_name):$(container_release) $(container_registry)/$(container_name):$(container_release)

tag-no-cache: build-no-cache
	docker tag $(container_name):$(container_release) $(container_registry)/$(container_name):$(container_release)

tag-timer-no-cache: build-timer-no-cache
	docker tag $(container_name):$(container_release) $(container_registry)/$(container_name):$(container_release)

push: tag
	docker push $(container_registry)/$(container_name):$(container_release)
