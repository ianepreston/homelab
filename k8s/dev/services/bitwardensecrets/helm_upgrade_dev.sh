#!/bin/env bash
helm upgrade sm-operator bitwarden/sm-operator -i --debug -n sm-operator-system --create-namespace --values dev-values.yaml --devel
