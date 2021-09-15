#!/usr/bin/env bash
mpdev verify --deployer=gcr.io/gke-istio-test-psb/tsb-operator/deployer:1.4 --parameters='{"name": "tsb", "namespace": "tsb","reportingSecret": "gs://cloud-marketplace-tools/reporting_secrets/fake_reporting_secret.yaml"}' | tee verify.log
