#!/bin/bash

set -euxo pipefail

mix local.hex --force
mix local.rebar --force
mix deps.get && mix compile
mix ecto.setup
