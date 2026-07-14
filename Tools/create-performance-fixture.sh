#!/bin/bash
set -euo pipefail

destination="${1:-${TMPDIR:-/tmp}/CleanSpace-Performance-Fixture}"
file_count="${CLEANSPACE_FIXTURE_FILES:-100001}"

mkdir -p "$destination/Library/Caches/PerformanceFixture"
root="$destination/Library/Caches/PerformanceFixture"

# Sparse logical capacity exercises >500 GB paths without consuming 500 GB of
# the developer's disk. CleanSpace still reports allocated bytes by design.
mkfile -n 501g "$root/large-sparse-model.bin"

index=0
while [ "$index" -lt "$file_count" ]; do
  shard=$(printf "%03d" $((index / 1000)))
  mkdir -p "$root/$shard"
  : > "$root/$shard/item-$index.cache"
  index=$((index + 1))
done

echo "$destination"
echo "Created $file_count files plus a 501 GB sparse logical file."
echo "Profile CleanSpaceDirect with Instruments using this path as an injected fixture home."
