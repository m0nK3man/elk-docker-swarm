.DEFAULT_GOAL:=help

COMPOSE_ALL_FILES := -f docker-compose.yml
SWARM_STACK_NAME = BSOC

compose_v2_not_supported = $(shell command docker compose 2> /dev/null)
ifeq (,$(compose_v2_not_supported))
  DOCKER_COMPOSE_COMMAND = docker-compose
else
  DOCKER_COMPOSE_COMMAND = docker compose
endif

# --------------------------
.PHONY: setup keystore certs all elk monitoring build down stop restart rm logs

# SETUP
keystore:		## Setup Elasticsearch Keystore, by initializing passwords, and add credentials defined in `keystore.sh`.
	$(DOCKER_COMPOSE_COMMAND) -f docker-compose.setup.yml run --rm keystore

certs:		    ## Generate Elasticsearch SSL Certs.
	$(DOCKER_COMPOSE_COMMAND) -f docker-compose.setup.yml run --rm certs

setup:		    ## Generate Elasticsearch SSL Certs and Keystore.
	@make certs
	@make keystore

# Docker Swarm section
swarm-deploy:   ## Deploy the ELK stack in Docker Swarm.
	set -a && . $(PWD)/.env && docker stack deploy -c docker-compose.yml $(SWARM_STACK_NAME)

swarm-down:     ## Remove the ELK stack in Docker Swarm.
	docker stack rm $(SWARM_STACK_NAME)

swarm-stop:     ## Stop all services in the ELK stack in Docker Swarm.
	@echo "Docker Swarm does not have a direct stop command, please use 'docker service scale' or 'docker stack rm'."

swarm-restart:  ## Restart all services in the ELK stack in Docker Swarm.
	@echo "Restarting services in the Swarm stack..."
	docker service update $(SWARM_STACK_NAME)_es-cluster
	docker service update $(SWARM_STACK_NAME)_logstash
	docker service update $(SWARM_STACK_NAME)_kibana

swarm-logs:     ## Tail logs for ELK services in Docker Swarm.
	docker service logs --follow --tail=1000 $(SWARM_STACK_NAME)_es-cluster
	docker service logs --follow --tail=1000 $(SWARM_STACK_NAME)_logstash
	docker service logs --follow --tail=1000 $(SWARM_STACK_NAME)_kibana

swarm-ps:       ## List all services in the ELK stack in Docker Swarm.
	watch docker stack ps --no-trunc $(SWARM_STACK_NAME)

# HELP
help:       	## Show this help.
	@echo "Make Application Docker Images and Containers using Docker-Compose files in 'docker' Dir."
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m (default: help)\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)


