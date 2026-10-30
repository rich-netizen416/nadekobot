#!/bin/sh

set -e

data_init="/app/data_init"
data="/app/data"

cp -R -n $data_init/* $data
if [ -f "$data_init/creds_example.yml" ]; then
    cp -n "$data_init/creds_example.yml" "$data/creds.yml"
fi

# Always overwrite native libraries to ensure updates are applied
mkdir -p "$data/lib"
rm -f "$data/lib/"*.so
cp -fL "$data_init/lib/"*.so "$data/lib/"

yt-dlp -U --quiet || true

exec "$@"