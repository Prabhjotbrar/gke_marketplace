#!/usr/bin/env bash
gcloud container clusters create tetrate --zone us-central1-c --machine-type n1-standard-4
make crd/install
