# app.Makefile provides the main targets for installing the application.
# It requires several APP_* variables defined as followed.
include ../app.Makefile
# crd.Makefile provides targets to install Application CRD.
include ../crd.Makefile
# gcloud.Makefile provides default values for REGISTRY and NAMESPACE derived from local
# gcloud and kubectl environments.
include ../gcloud.Makefile
include ../var.Makefile

# Container repo
REGISTRY := gcr.io/sam-playground-290106/tsb-operator

$(info ---- REGISTRY = $(REGISTRY))

CHART_NAME := tsb-operator
$(info ---- CHART_NAME = $(CHART_NAME))

OPERATOR_TAG ?= 1.3.0
$(info ---- OPERATOR_TAG = $(OPERATOR_TAG))

POSTGRES_VERSION ?= 11.13.0
ELASTIC_VERSION ?= 7.14.0
ECK_OPERATOR_TAG ?= 1.7.1
KUBECTL_TAG ?= 1.20.10

# Deployer tag is used for displaying versions in partner portal.
# This version only support major.minor so the Redis version major.minor.patch
# is converted into more readable form of major.2 digit zero padded minor + patch
# without the hyphen
DEPLOYER_TAG ?= 1.4
$(info ---- DEPLOYER_TAG = $(DEPLOYER_TAG))

# Tag the deployer image with modified version.
APP_DEPLOYER_IMAGE := $(REGISTRY)/deployer:$(DEPLOYER_TAG)

NAME ?= tsb-operator
NAMESPACE ?= tsb

APP_PARAMETERS ?= { \
  "APP_INSTANCE_NAME": "$(NAME)", \
  "NAMESPACE": "$(NAMESPACE)" \
}

TESTER_IMAGE ?= $(REGISTRY)/tester:$(OPERATOR_TAG)

app/build:: .build/tsb-operator/deployer \
			.build/tsb-operator/primary \
			.build/tsb-operator/eck-operator \
			.build/tsb-operator/bitnami-kubectl \
            .build/tsb-operator/tester


.build/tsb-operator: | .build
	mkdir -p "$@"

.build/tsb-operator/deployer: deployer/* \
								  chart/**/* \
                                  schema.yaml \
                                  .build/var/APP_DEPLOYER_IMAGE \
                                  .build/var/MARKETPLACE_TOOLS_TAG \
                                  .build/var/REGISTRY \
                                  .build/var/OPERATOR_TAG \
								  .build/var/CHART_NAME \
                                  | .build/tsb-operator
	$(call print_target, $@)
	docker build \
	    --build-arg REGISTRY="$(REGISTRY)" \
	    --build-arg TAG="$(OPERATOR_TAG)" \
	    --build-arg CHART_NAME="$(CHART_NAME)" \
	    --build-arg MARKETPLACE_TOOLS_TAG="$(MARKETPLACE_TOOLS_TAG)" \
	    --tag "$(APP_DEPLOYER_IMAGE)" \
	    -f deployer/Dockerfile \
	    .
	docker push "$(APP_DEPLOYER_IMAGE)"
	@touch "$@"

.build/tsb-operator/eck-operator: .build/var/REGISTRY \
										  .build/var/ECK_OPERATOR_TAG \
                                          | .build/tsb-operator
	$(call print_target, $@)
	docker pull docker.elastic.co/eck/eck-operator:$(ECK_OPERATOR_TAG)
	docker tag docker.elastic.co/eck/eck-operator:$(ECK_OPERATOR_TAG) "$(REGISTRY)/eck-operator:$(ECK_OPERATOR_TAG)"
	docker push "$(REGISTRY)/eck-operator:$(ECK_OPERATOR_TAG)"
	@touch "$@"

.build/tsb-operator/bitnami-kubectl: .build/var/REGISTRY \
										  .build/var/KUBECTL_TAG \
                                          | .build/tsb-operator
	$(call print_target, $@)
	docker pull bitnami/kubectl:$(KUBECTL_TAG)
	docker tag bitnami/kubectl:$(KUBECTL_TAG) "$(REGISTRY)/kubectl:$(KUBECTL_TAG)"
	docker push "$(REGISTRY)/kubectl:$(KUBECTL_TAG)"
	@touch "$@"

# Operator image is the primary image for Redis Enterprise.
# Label the primary image with the same tag as deployer image.
# From the partner portal, primary image is queried using the same tag
# as deployer image. When pulling the image from docker hub use
# the redis native tag and push that image as primary image with deployer tag.
.build/tsb-operator/primary: .build/var/REGISTRY \
										  .build/var/OPERATOR_TAG \
                                          | .build/tsb-operator
	$(call print_target, $@)
	docker pull gcr.io/gke-istio-test-psb/tsboperator-server:$(OPERATOR_TAG)
	docker tag gcr.io/gke-istio-test-psb/tsboperator-server:$(OPERATOR_TAG) "$(REGISTRY):$(OPERATOR_TAG)"
	docker push "$(REGISTRY):$(OPERATOR_TAG)"
	@touch "$@"

.build/tsb-operator/tester: apptest/**/* \
                                | .build/tsb-operator
	$(call print_target, $@)
	cd apptest/tester \
	    && docker build --tag "$(TESTER_IMAGE)" .
	docker push "$(TESTER_IMAGE)"
	@touch "$@"
