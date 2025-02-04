#!/usr/bin/env bash
# Copyright 2023 SAP SE or an SAP affiliate company. All rights reserved. This file is licensed under the Apache Software License, v. 2 except as noted otherwise in the LICENSE file.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


set -o errexit
set -o nounset
set -o pipefail

SKAFFOLD_PROFILE=""

parse_flags() {
  while test $# -gt 0; do
    case "$1" in
    --skaffold-profile)
      shift; SKAFFOLD_PROFILE="-p $1"
      ;;
    esac

    shift
  done
}

parse_flags "$@"

# delete stuff gradually in the right order, otherwise several dependencies will prevent the cleanup from succeeding
kubectl delete seed \
  local \
  local2 \
  local-ha-single-zone \
  local-ha-multi-zone \
  --ignore-not-found \
  --wait \
  --timeout 5m

skaffold delete -m provider-local,gardenlet $SKAFFOLD_PROFILE

kubectl delete validatingwebhookconfiguration/gardener-admission-controller --ignore-not-found
kubectl annotate project local garden confirmation.gardener.cloud/deletion=true

skaffold delete -m local-env $SKAFFOLD_PROFILE
skaffold delete -m etcd,controlplane $SKAFFOLD_PROFILE

# workaround for https://github.com/gardener/gardener/issues/5164
kubectl delete ns \
  seed-local \
  seed-local2 \
  seed-local-ha-single-zone \
  seed-local-ha-multi-zone \
  --ignore-not-found

# cleanup namespaces that don't get deleted automatically
kubectl delete ns gardener-system-seed-lease --ignore-not-found
