#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${0}")/teamcity-support.sh"

tc_start_block "Prepare environment"
# Grab a testing license good for one hour.
COCKROACH_DEV_LICENSE=$(curl -f "https://register.cockroachdb.com/api/prodtest")
run mkdir -p artifacts
maybe_ccache
tc_end_block "Prepare environment"

tc_start_block "Compile CockroachDB"
# Buffer noisy output and only print it on failure.
run build/builder.sh make build &> artifacts/roachtests-compile.log || (cat artifacts/roachtests-compile.log && false)
rm artifacts/roachtests-compile.log
tc_end_block "Compile CockroachDB"

tc_start_block "Compile roachprod/workload/roachtest"
run build/builder.sh make bin/roachprod bin/workload bin/roachtest
tc_end_block "Compile roachprod/workload/roachtest"

tc_start_block "Run local roachtests"
echo "Test parsing does not work here, see https://youtrack.jetbrains.com/issue/TW-63449"
echo "Consult artifacts/failures.txt instead"
# TODO(peter,dan): curate a suite of the tests that works locally.
# NB: roachtest doesn't support -json so we have to use run_text_test.
run_text_test pkg/cmd/roachtest build/builder.sh env COCKROACH_DEV_LICENSE="$COCKROACH_DEV_LICENSE" \
  stdbuf -oL -eL \
  ./bin/roachtest run acceptance kv/splits cdc/bank \
  --local \
  --parallelism=1 \
  --cockroach "cockroach" \
  --roachprod "bin/roachprod" \
  --workload "bin/workload" \
  --artifacts artifacts \
  --teamcity
tc_end_block "Run local roachtests"
