# where to download files too
BIN_DIR = .bin

SRC := $(shell find . \( -path './.git' -o -path './.docker.log' -o -path './.dockerid' -o -path './tests/venv' \) -prune -o -print)

DOCKER_HOST ?= unix:///var/run/docker.sock
DOCKER_BUILD_ARGS ?= --build-arg http_proxy=$(http_proxy) --build-arg https_proxy=$(https_proxy)

CIDFILE ?= .cidfile

# docker_taskgraph command
#TASKGRAPH := $(BIN_DIR)/docker-taskgraph
#TASKGRAPH_EXTRA ?= 

APPNAME := haproxy
DOCKERID := .dockerid

MAKECERTS := $(BIN_DIR)/makecerts

.PHONY: run run-it enter-it testcerts test test-list tar

all: .dockerid

$(MAKECERTS):
	mkdir -p $(BIN_DIR)
	curl -s -o $@ -z $@ "https://github.com/wrouesnel/makecerts/releases/download/v0.4/makecerts.x86_64"
	chmod +x $@

.dockerid: $(SRC)
	docker build --iidfile=$(DOCKERID) $(DOCKER_BUILD_ARGS) $(EXTRA_BUILD_ARGS) $(APPNAME)

tar: $(APPNAME).tar

$(APPNAME).tar: $(DOCKERID)
	docker save -o $(APPNAME).tar $(shell cat $(DOCKERID))

#test: $(DOCKERID) $(TASKGRAPH)
#	DOCKER_IMAGE=$(shell cat $(DOCKERID)) DOCKER_PREFIX=$(DOCKER_PREFIX) DOCKERHUB_PREFIX=$(DOCKERHUB_PREFIX) $(TASKGRAPH) \
#	--build-arg=http_proxy=$(http_proxy) --build-arg=https_proxy=$(https_proxy) \
#	--build-arg=DOCKERHUB_PREFIX=$(DOCKERHUB_PREFIX) --build-arg=DOCKER_PREFIX=$(DOCKER_PREFIX) \
#	--dir tests/integration run --junit-xml-output=test_results.xml $(TASKGRAPH_EXTRA)

#test-list: $(DOCKERID) $(TASKGRAPH)
#	DOCKER_IMAGE=$(shell cat $(DOCKERID)) $(TASKGRAPH) \
#	--build-arg http_proxy=$(http_proxy) --build-arg=https_proxy=$(https_proxy) \
#	--build-arg=DOCKERHUB_PREFIX=$(DOCKERHUB_PREFIX) --build-arg=DOCKER_PREFIX=$(DOCKER_PREFIX) \
#	--dir tests/integration list $(TASKGRAPH_EXTRA)

enter-it: $(DOCKERID)
	rm -f $(CIDFILE)
	docker run -e SSL_CLIENT_CACERT=disabled -e DEV_ALLOW_SELF_SIGNED=yes \
		-e DEV_ALLOW_EPHEMERAL_DATA=yes -e API_AUTH=disabled \
		-e DEV_ALLOW_DEFAULT_TRUST=yes -e DEV_NO_ALERT_EMAILS=yes -e DEV_NO_SMARTHOST=yes \
		--tmpfs /run:suid,exec --tmpfs /tmp:suid,exec --tmpfs /data:suid,exec \
		--read-only --entrypoint=/bin/bash \
		-it --rm --cidfile=$(CIDFILE) $(EXTRA_RUN_ARGS) `cat $(DOCKERID)`
		
run-it: $(DOCKERID)
	rm -f $(CIDFILE)
	docker run -e SSL_CLIENT_CACERT=disabled -e DEV_ALLOW_SELF_SIGNED=yes \
		-e DEV_ALLOW_EPHEMERAL_DATA=yes -e ADMIN_AUTH=disabled -e DEV_STANDALONE=yes \
		-e DEV_ALLOW_DEFAULT_TRUST=yes -e DEV_NO_ALERT_EMAILS=yes -e DEV_NO_SMARTHOST=yes \
		--tmpfs /run:suid,exec --tmpfs /tmp:suid,exec --tmpfs /data:suid,exec \
		--read-only \
		-it --rm --cidfile=$(CIDFILE) $(EXTRA_RUN_ARGS) `cat $(DOCKERID)`

run: $(DOCKERID)
	rm -f $(CIDFILE)
	docker run --rm --cidfile=$(CIDFILE) `cat $(DOCKERID)`

# Exec's into the most recently run container.
exec-into:
	docker exec -it $(shell cat $(CIDFILE)) /bin/bash

init-it:
	wget -O - --no-check-certificate \
		"https://$(shell docker inspect -f '{{ .NetworkSettings.IPAddress }}' $(shell cat $(CIDFILE)))/info/schema.standalone.pgsql.sql" \
		| docker exec -i $(shell cat $(CIDFILE)) psql "dbname=pdns user=powerdns"

get-ip:
	@docker inspect -f '{{ .NetworkSettings.IPAddress }}' $(shell cat $(CIDFILE))

clean:
	rm -f $(CIDFILE) $(DOCKERID)
	
testcerts: $(MAKECERTS)
	mkdir -p .certs
	cd .certs \
		&& $(MAKECERTS) --name-suffix="psql" postgres powerdns 172.20.0.1 172.20.0.2 172.20.0.3 172.20.0.4 172.20.0.5 \
		&& $(MAKECERTS) --name-suffix="psql-client" postgres powerdns \
		&& $(MAKECERTS) --name-suffix="nginx" postgres powerdns 172.20.0.1 172.20.0.2 172.20.0.3 172.20.0.4 172.20.0.5
