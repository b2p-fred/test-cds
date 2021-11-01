#!/bin/bash
# -----
# Run this script to start CDS configuration
# -----
#### set -e

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
CDS_PROJECT=${CDS_PROJECT:-EPR}
CDS_APPLICATION=${CDS_APPLICATION:-backend}

usage() {
  cat <<END

Usage: $0 [-q | --quiet] [-H|-h|--help] command [project] [application]

  -h (-H) (--help)    display this message
  -q (--quiet)        quiet mode (default is to dump information to the console)

  command is one of:
  - project
  - application

  some configuration variables are defined in the .env file -)
END
}

if [ $# -lt 1 ]; then
    usage >&1
    exit 1
fi

for i in "$@"; do
  if [ "$i" != "" ]; then
    case $i in
    -h | -H | --help)
      usage >&1
      exit 0
      ;;
    -q | --quiet)
      VERBOSE_MODE="0"
      shift
      ;;
    *)
      COMMAND=$i
      shift
      [ "$1" != "" ] && CDS_PROJECT=$(echo "$1" | tr '[:lower:]' '[:upper:]')
      [ "$2" != "" ] && CDS_APPLICATION=$(echo "$2" | tr '[:upper:]' '[:lower:]')
      break
      ;;
    esac
  fi
done

[ "$VERBOSE_MODE" = "1" ] && echo "Verbose mode is on"
[ "$VERBOSE_MODE" = "1" ] && echo "Command: $COMMAND, project: $CDS_PROJECT, application: $CDS_APPLICATION"
[ "$VERBOSE_MODE" = "1" ] && echo "---"

# Project configuration
if [ "$COMMAND" = "project" ]; then
  [ "$VERBOSE_MODE" = "1" ] && echo "* Creating and configuring project..."
  ./cdsctl project create --no-interactive "$CDS_PROJECT" "eProtocole" || true
  ./cdsctl project favorite "$CDS_PROJECT"
  ./cdsctl project variable add "$CDS_PROJECT" DOCKER_REGISTRY string docker.b2pweb.com:5000/
  ./cdsctl project variable add "$CDS_PROJECT" DOCKER_REGISTRY_USERNAME string integration
  ./cdsctl project variable add "$CDS_PROJECT" DOCKER_REGISTRY_PASSWORD string integration
  ./cdsctl project variable add "$CDS_PROJECT" DOCKER_PREFIX string eprotocole/
  ./cdsctl project variable add "$CDS_PROJECT" IMAGE_TAG_DB string 1
  ./cdsctl project variable add "$CDS_PROJECT" IMAGE_TAG_NGINX string 5
  ./cdsctl project variable add "$CDS_PROJECT" IMAGE_TAG_PHP string 3
  ./cdsctl project variable add "$CDS_PROJECT" PROJECT string eProtocole
  ./cdsctl project variable add "$CDS_PROJECT" PROJECT_LEVEL string 0
  ./cdsctl project variable add "$CDS_PROJECT" PROJECT_API_VERSION string 0.0.0-dev.2
  ./cdsctl project variable add "$CDS_PROJECT" PROJECT_PWA_VERSION string 0.0.0-dev.1

  ./cdsctl project variable list "$CDS_PROJECT"

  exit 0
fi

# Applications configuration
if [ "$COMMAND" = "application" ]; then
  [ "$VERBOSE_MODE" = "1" ] && echo "* Creating and configuring application..."
  ./cdsctl application create "$CDS_PROJECT" "$CDS_APPLICATION"
  ./cdsctl application variable add "$CDS_PROJECT" "$CDS_APPLICATION" APP_ENV string "{{.cds.env.APP_ENV}}"
  ./cdsctl application variable add "$CDS_PROJECT" "$CDS_APPLICATION" DISCORD_AVATAR string "$DISCORD_AVATAR"
  ./cdsctl application variable add "$CDS_PROJECT" "$CDS_APPLICATION" DISCORD_URL string "$DISCORD_URL"
  ./cdsctl application variable list "$CDS_PROJECT" "$CDS_APPLICATION"

  exit 0
fi

# Worker models
if [ "$COMMAND" = "workers" ]; then
  [ "$VERBOSE_MODE" = "1" ] && echo "* Importing worker models..."
  ./cdsctl worker model import ./data/worker-models/epr-php.0.yml

  exit 0
fi

# Actions
if [ "$COMMAND" = "actions" ]; then
  [ "$VERBOSE_MODE" = "1" ] && echo "* Importing actions..."
  ./cdsctl action import ./data/actions/cds-b2p-discord-notification.yml
  ./cdsctl action import ./data/actions/cds-b2p-docker-login.yml
  ./cdsctl action import ./data/actions/cds-b2p-docker-logout.yml

  exit 0
fi

# Pipelines
if [ "$COMMAND" = "pipelines" ]; then
  [ "$VERBOSE_MODE" = "1" ] && echo "* Importing pipelines..."
  ./cdsctl pipeline import "$CDS_PROJECT" ./data/pipelines/epr-docker-pull.yml

  exit 0
fi

# Workflows
if [ "$COMMAND" = "workflows" ]; then
  [ "$VERBOSE_MODE" = "1" ] && echo "* Importing workflows..."
  ./cdsctl pipeline import "$CDS_PROJECT" ./data/workflows/epr-docker-pull.yml

  exit 0
fi
