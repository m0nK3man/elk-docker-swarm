.DEFAULT_GOAL:=help

COMPOSE_ALL_FILES := -f docker-compose.yml
ELK_ALL_SERVICES   := elasticsearch logstash kibana
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

# Docker-compose section
elk:		    ## Start ELK.
	$(DOCKER_COMPOSE_COMMAND) up -d --build

up:
	@make elk
	@echo "Visit Kibana: https://localhost:5601 (user: elastic, password: changeme) [Unless you changed values in .env]"

ps:				## Show all running containers.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_ALL_FILES} ps

down:			## Down ELK and all its extra components.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_ALL_FILES} down

stop:			## Stop ELK and all its extra components.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_ALL_FILES} stop ${ELK_ALL_SERVICES}

restart:		## Restart ELK and all its extra components.
	$(DOCKER_COMPOSE_COMMAND) ${COMPOSE_ALL_FILES} restart ${ELK_ALL_SERVICES}

rm:				## Remove ELK and all its extra components containers.
	$(DOCKER_COMPOSE_COMMAND) $(COMPOSE_ALL_FILES) rm -f ${ELK_ALL_SERVICES}

logs:			## Tail all logs with -n 1000.
	$(DOCKER_COMPOSE_COMMAND) $(COMPOSE_ALL_FILES) logs --follow --tail=1000 ${ELK_ALL_SERVICES}

images:			## Show all Images of ELK and all its extra components.
	$(DOCKER_COMPOSE_COMMAND) $(COMPOSE_ALL_FILES) images ${ELK_ALL_SERVICES}

prune:			## Remove ELK Containers and Delete ELK-related Volume Data (the elastic_elasticsearch-data volume)
	@make stop && make rm
	@docker volume prune -f --filter label=com.docker.compose.project=elastic


# Docker Swarm section
swarm-deploy:   ## Deploy the ELK stack in Docker Swarm.
	set -a && . $(PWD)/.env && docker stack deploy -c docker-compose.yml $(SWARM_STACK_NAME)

swarm-down:     ## Remove the ELK stack in Docker Swarm.
	docker stack rm $(SWARM_STACK_NAME)

swarm-stop:     ## Stop all services in the ELK stack in Docker Swarm.
	@echo "Docker Swarm does not have a direct stop command, please use 'docker service scale' or 'docker stack rm'."

swarm-restart:  ## Restart all services in the ELK stack in Docker Swarm.
	@echo "Restarting services in the Swarm stack..."
	docker service update $(SWARM_STACK_NAME)_elasticsearch
	docker service update $(SWARM_STACK_NAME)_logstash
	docker service update $(SWARM_STACK_NAME)_kibana

swarm-logs:     ## Tail logs for ELK services in Docker Swarm.
	docker service logs --follow --tail=1000 $(SWARM_STACK_NAME)_elasticsearch
	docker service logs --follow --tail=1000 $(SWARM_STACK_NAME)_logstash
	docker service logs --follow --tail=1000 $(SWARM_STACK_NAME)_kibana

swarm-ps:       ## List all services in the ELK stack in Docker Swarm.
	watch docker stack ps $(SWARM_STACK_NAME)


# HELP
help:       	## Show this help.
	@echo "Make Application Docker Images and Containers using Docker-Compose files in 'docker' Dir."
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m (default: help)\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)


