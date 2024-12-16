#!/bin/bash

podman machine rm --force
for i in kubectl helm kind podman 
do
  brew uninstall --force --zap --casks $i
done

rm -fr terraform.tfstate.backup terraform.tfstate
rm -fr .terraform.lock.hcl

