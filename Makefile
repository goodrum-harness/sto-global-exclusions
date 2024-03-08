# Makefile
# Standard top-level shared Makefile switchboard to consolidate all common
# rules which will be used when testing or executing this repository.
#

# Auto-include a Makefile.local if it exists in this local directory
ifneq ("$(wildcard Makefile.local)", "")
	include Makefile.local
endif

ifeq ($(DOCKER_COMMAND),)
	DOCKER_COMMAND=docker
endif
ifeq ($(DOCKER_IMAGE),)
	DOCKER_IMAGE=harness-sto-exclusion-manager
endif
ifeq ($(DOCKER_TAG),)
	DOCKER_TAG=latest
endif
ifeq ($(DOCKER_ENV),)
	DOCKER_ENV:=
endif
ifeq ($(DOCKER_MOUNTS),)
	DOCKER_MOUNTS:=
endif
ifeq ($(PROJECT_DIR),)
	PROJECT_DIR:=${PWD}
endif
ifeq ($(TEMPLATE_DIR),)
	TEMPLATE_DIR:=
endif
WORKDIR=/harness
DOCKER_RUN=${DOCKER_COMMAND} run --rm -it ${DOCKER_ENV} -v ${PROJECT_DIR}:/${WORKDIR} ${DOCKER_MOUNTS} -w ${WORKDIR}/${TEMPLATE_DIR} $(ENTRYPOINT) ${DOCKER_IMAGE}:${DOCKER_TAG}


.PHONY: debug
debug:
	$(eval ENTRYPOINT=--entrypoint bash)
	@(${DOCKER_RUN})

.PHONY: build
build:
	${DOCKER_COMMAND} build ${BUILD_FLAGS} -f docker/Dockerfile ${DOCKER_ARGS_CMD} -t ${DOCKER_IMAGE}:${DOCKER_TAG} docker

.PHONY: push
push:
	${DOCKER_COMMAND} push --all-platforms ${DOCKER_IMAGE}:${DOCKER_TAG}

.PHONY: run
run:
	(${DOCKER_RUN} /app/sto-override-handler.sh -w /harness -s owasp -o default -p Local_Testing -P jim)
