#!/bin/sh
set -eu

if [ "$#" -ne 3 ]; then
  echo "usage: $0 <youtube-input.json> <x-input.json> <douyin-input.json>" >&2
  exit 2
fi
command -v apify >/dev/null 2>&1 || { echo "apify-cli is required" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq is required" >&2; exit 1; }
if [ -z "${APIFY_TOKEN:-}" ]; then
  echo "APIFY_TOKEN is required" >&2
  exit 1
fi

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$root"
if [ -f .env ]; then
  set -a
  . ./.env
  set +a
fi

tmpdir=$(mktemp -d)
trap 'rm -rf -- "$tmpdir"' EXIT

run_actor() {
  platform=$1
  actor=$2
  input_file=$3
  run_json=$(apify actors call "$actor" \
    --input-file "$input_file" \
    --user-agent apify-agent-skills/apify-ultimate-scraper \
    --json 2>/dev/null)
  dataset_id=$(printf '%s' "$run_json" | jq -r '.defaultDatasetId // empty')
  if [ -z "$dataset_id" ]; then
    echo "Apify did not return a dataset for $platform" >&2
    exit 1
  fi
  apify datasets get-items "$dataset_id" \
    --user-agent apify-agent-skills/apify-ultimate-scraper \
    --format json > "$tmpdir/$platform.json" 2>/dev/null
  go run ./cmd/importvideos \
    -platform "$platform" \
    -input "$tmpdir/$platform.json"
}

run_actor youtube streamers/youtube-scraper "$1"
run_actor x apidojo/tweet-scraper "$2"
run_actor douyin clockworks/tiktok-scraper "$3"
