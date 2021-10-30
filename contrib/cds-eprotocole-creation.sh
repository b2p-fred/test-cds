#!/bin/bash

# Default is verbose mode
VERBOSE_MODE="1"

usage() {
  cat <<END

Usage: $0 [-q | --quiet] [-H|-h|--help]

  -h (-H) (--help)    display this message
  -q (--quiet)        quiet mode (default is to dump information to the console)

  the version tag used is defined in the .env file -)
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

if [ "$VERBOSE_MODE" = "1" ]; then
  echo "----------"
  echo "Verbose mode is on"
  echo "----------"
fi

[ "$VERBOSE_MODE" = "1" ] && echo "Verbose mode is on"

exit
# Project configuration
./cdsctl project create --no-interactive EPROT "eProtocole"
./cdsctl project favorite EPROT
./cdsctl project variable add EPROT DOCKER_REGISTRY string docker.b2pweb.com:5000/
./cdsctl project variable add EPROT DOCKER_REGISTRY_USERNAME string integration
./cdsctl project variable add EPROT DOCKER_REGISTRY_PASSWORD string integration
./cdsctl project variable add EPROT DOCKER_PREFIX string eprotocole/
./cdsctl project variable add EPROT PROJECT string eProtocole
./cdsctl project variable add EPROT PROJECT_VERSION string 0
./cdsctl project variable add EPROT PROJECT_API_VERSION string 0.0.0-dev.2
./cdsctl project variable add EPROT PROJECT_PWA_VERSION string 0.0.0-dev.1

# Applications configuration
./cdsctl application create EPROT backend
./cdsctl application create EPROT frontend
