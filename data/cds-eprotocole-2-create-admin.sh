#!/bin/bash
# -----
# Run this script to create the CDS admin user
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


# create user
if [ ! -f cdsctl ] ; then
  [ "$VERBOSE_MODE" = "1" ] && echo "* Fetching cdsctl..."
  curl "$CDS_API_URL/download/cdsctl/linux/amd64?variant=nokeychain" -o cdsctl
  # on OSX: $ curl "$CDS_API_URL/download/cdsctl/darwin/amd64?variant=nokeychain" -o cdsctl
  chmod +x cdsctl
fi
[ "$VERBOSE_MODE" = "1" ] && echo "* Creating an admin user '$CDS_ADMIN_USER'..."
./cdsctl signup --api-url "$CDS_API_URL" --email "$CDS_ADMIN_USER"@localhost.local --username "$CDS_ADMIN_USER" --fullname "$CDS_ADMIN_USER"
# enter a strong password

# verify the user
#$ VERIFY_CMD=$(docker-compose logs cds-api|grep 'cdsctl signup verify'|cut -d '$' -f2|xargs) && ./$VERIFY_CMD
[ "$VERBOSE_MODE" = "1" ] && echo "* Verifying admin user..."
VERIFY_CMD=$(docker-compose logs cds-api|grep 'cdsctl signup verify'|tail -n1|cut -d '$' -f2|xargs)
[ "$VERBOSE_MODE" = "1" ] && echo "* VERIFY_CMD = $VERIFY_CMD"
./$VERIFY_CMD
[ "$VERBOSE_MODE" = "1" ] && echo "* done"
# if you have this error:  "such file or directory: ./cdsctl signup verify --api-url...",
# you can manually execute the command "./cdsctl signup verify --api-url..."
# dump my user information
[ "$VERBOSE_MODE" = "1" ] && echo "* Dumping user information..."
./cdsctl user me

# run others services
[ "$VERBOSE_MODE" = "1" ] && echo "* Running some more services..."
docker-compose up -d cds-ui cds-cdn cds-hooks cds-elasticsearch cds-hatchery-swarm
