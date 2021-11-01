#!/bin/bash
# -----
# Run this script to start CDS installation
# -----
set -e

# -----
# NOTE: this script has some configuration variables
# -----
# If an .env file exists, source its defined variables
if [ ! -f .env ]
then
  if [ -f .env.dist ]
  then
    cp .env.dist .env
  fi
fi
if [ -f .env ]
then
  export $(cat .env | sed 's/#.*//g' | xargs)
fi

# Default is verbose mode
VERBOSE_MODE=${VERBOSE_MODE:-1}

HOSTNAME=${HOSTNAME:-$(hostname)}

CDS_VERSION=${CDS_VERSION:-0.49.0}
CDS_DOCKER_IMAGE=${CDS_DOCKER_IMAGE:-ovhcom/cds-engine:latest}
CDS_API_URL=${CDS_API_URL:-http://localhost:8081}
CDS_ADMIN_USER=${CDS_ADMIN_USER:-admin}

usage() {
  cat <<END

Usage: $0 [-q | --quiet] [-H|-h|--help]

  -h (-H) (--help)    display this message
  -q (--quiet)        quiet mode (default is to dump information to the console)

  some configuration variables are defined in the .env file -)
END
}

for i in "$@"; do
  case $i in
  -h | -H | --help)
    usage >&1
    exit 0
    ;;
  -q | --quiet)
    VERBOSE_MODE="0"
    shift
    ;;
  esac
done

[ "$VERBOSE_MODE" = "1" ] && echo "Verbose mode is on"
[ "$VERBOSE_MODE" = "1" ] && echo "Local hostname is ${HOSTNAME}"
[ "$VERBOSE_MODE" = "1" ] && echo "CDS engine Docker image: ${CDS_DOCKER_IMAGE}"
[ "$VERBOSE_MODE" = "1" ] && echo "---"

# CDS installation
mkdir -p tools/smtpmock

if [ ! -f docker-compose.yml ] ; then
  [ "$VERBOSE_MODE" = "1" ] && echo "* Fetching docker-compose.yml..."
  curl https://raw.githubusercontent.com/ovh/cds/${CDS_VERSION}/docker-compose.yml -o docker-compose.yml
else
  [ "$VERBOSE_MODE" = "1" ] && echo "* Using the existing docker-compose.yml file."
fi

# Get the CDS engine Docker image
if [[ "$(docker images -q ${CDS_DOCKER_IMAGE} 2> /dev/null)" == "" ]]; then
  [ "$VERBOSE_MODE" = "1" ] && echo "* Pulling CDS engine Docker image..."
  docker pull ${CDS_DOCKER_IMAGE}
fi

# Create PostgreSQL database, redis and elasticsearch
[ "$VERBOSE_MODE" = "1" ] && echo "* Starting database, cache and elasticsearch..."
docker-compose up --no-recreate -d cds-db cds-cache elasticsearch dockerhost
sleep 1
[ "$VERBOSE_MODE" = "1" ] && echo "* Initializing database..."
docker-compose up --no-recreate cds-db-init
# You should have this log: "cdstest_cds-migrate_1 exited with code 0"
[ "$VERBOSE_MODE" = "1" ] && echo "* Migrating database..."
docker-compose up --no-recreate cds-migrate
# You should have this log: "cdstest_cds-migrate_1 exited with code 0"

[ "$VERBOSE_MODE" = "1" ] && echo "* Preparing initial configuration..."
docker-compose up cds-prepare

[ "$VERBOSE_MODE" = "1" ] && echo "* Extracting INIT_TOKEN from the log..."
# the INIT_TOKEN variable will be used by cdsctl to create the admin user
# get the last one in the log!
TOKEN_CMD=$(docker logs test-cds_cds-prepare_1|grep INIT_TOKEN)
TOKEN_CMD=$(echo "$TOKEN_CMD" | tail -n1)
export INIT_TOKEN=$(echo "$TOKEN_CMD"|cut -d '=' -f2)

# disable the smtp server
[ "$VERBOSE_MODE" = "1" ] && echo "* Disabling the SMTP server configuration..."
export CDS_EDIT_CONFIG="api.smtp.disable=true"
docker-compose up cds-edit-config

# configure API and UI url
[ "$VERBOSE_MODE" = "1" ] && echo "* Configuring API and UI base URL..."
export CDS_EDIT_CONFIG="api.url.api=$CDS_API_URL"
docker-compose up cds-edit-config
export CDS_EDIT_CONFIG="api.url.ui=http://localhost:8080"
docker-compose up cds-edit-config

# run API
[ "$VERBOSE_MODE" = "1" ] && echo "* Starting the API..."
docker-compose up -d cds-api

[ "$VERBOSE_MODE" = "1" ] && echo "* ---"
[ "$VERBOSE_MODE" = "1" ] && echo "* execute the command export INIT_TOKEN"
[ "$VERBOSE_MODE" = "1" ] && echo "* ---"

# run others services
[ "$VERBOSE_MODE" = "1" ] && echo "* Running some more services..."
docker-compose up -d cds-ui cds-cdn cds-hooks cds-elasticsearch cds-hatchery-swarm
