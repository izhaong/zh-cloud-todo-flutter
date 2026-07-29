#!/usr/bin/env bash
set -euo pipefail

jenkinsfile="${1:-Jenkinsfile}"

grep -Fq "ghcr.io/cirruslabs/flutter:3.44.0" "$jenkinsfile"
grep -Fq 'retry(3)' "$jenkinsfile"
grep -Fq 'img.pull()' "$jenkinsfile"
! grep -Fq 'params.FLUTTER_DOCKER_IMAGE' "$jenkinsfile"
