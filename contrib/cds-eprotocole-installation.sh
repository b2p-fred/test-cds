#!/bin/bash
set -e

# Default is verbose mode
VERBOSE_MODE="1"

export HOSTNAME=$(hostname)
export CDS_VERSION=0.49.0
export CDS_DOCKER_IMAGE=ovhcom/cds-engine:${CDS_VERSION:-latest}

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

[ "$VERBOSE_MODE" = "1" ] && echo "Verbose mode is on"
[ "$VERBOSE_MODE" = "1" ] && echo "Local hostname is ${HOSTNAME}"
[ "$VERBOSE_MODE" = "1" ] && echo "CDS engine Docker image: ${CDS_DOCKER_IMAGE}"
[ "$VERBOSE_MODE" = "1" ] && echo "---"


# CDS installation
mkdir -p tools/smtpmock

[ "$VERBOSE_MODE" = "1" ] && echo "* Fetching docker-compose.yml..."
[ ! -f docker-compose.yml ] && curl https://raw.githubusercontent.com/ovh/cds/${CDS_VERSION}/docker-compose.yml -o docker-compose.yml

# Get the latest version
[ "$VERBOSE_MODE" = "1" ] && echo "* Pulling CDS engine..."
docker pull ${CDS_DOCKER_IMAGE}

# Create PostgreSQL database, redis and elasticsearch
[ "$VERBOSE_MODE" = "1" ] && echo "* Starting database, cache and elasticsearch..."
docker-compose up --no-recreate -d cds-db cds-cache elasticsearch dockerhost
sleep 3
[ "$VERBOSE_MODE" = "1" ] && echo "* Initializing database..."
docker-compose up --no-recreate cds-db-init
# You should have this log: "cdstest_cds-migrate_1 exited with code 0"
[ "$VERBOSE_MODE" = "1" ] && echo "* Migrating database..."
docker-compose up --no-recreate cds-migrate
# You should have this log: "cdstest_cds-migrate_1 exited with code 0"

[ "$VERBOSE_MODE" = "1" ] && echo "* Preparing initial configuration..."
docker-compose up cds-prepare

[ "$VERBOSE_MODE" = "1" ] && echo "* Extracting INIT_TOKEN from the log..."
# the INIT_TOKEN variable will be used by cdsctl to create first admin user
TOKEN_CMD=$(docker logs cds_cds-prepare_1|grep INIT_TOKEN)
export INIT_TOKEN=$(echo $TOKEN_CMD|cut -d '=' -f2)

[ "$VERBOSE_MODE" = "1" ] && echo "* INIT_TOKEN = $INIT_TOKEN"

# disable the smtp server
[ "$VERBOSE_MODE" = "1" ] && echo "* Disabling the SMTP server configuration..."
export CDS_EDIT_CONFIG="api.smtp.disable=true"
docker-compose up cds-edit-config

# configure UI url
[ "$VERBOSE_MODE" = "1" ] && echo "* Configuring UI base URL..."
export CDS_EDIT_CONFIG="api.url.ui=http://localhost:8080"
docker-compose up cds-edit-config

# run API
[ "$VERBOSE_MODE" = "1" ] && echo "* Starting the API..."
$ docker-compose up -d cds-api
exit


# create user
$ curl 'http://localhost:8081/download/cdsctl/linux/amd64?variant=nokeychain' -o cdsctl
# on OSX: $ curl 'http://localhost:8081/download/cdsctl/darwin/amd64?variant=nokeychain' -o cdsctl
$ chmod +x cdsctl
$ ./cdsctl signup --api-url http://localhost:8081 --email admin@localhost.local --username admin --fullname admin
# enter a strong password

# verify the user
$ VERIFY_CMD=$(docker-compose logs cds-api|grep 'cdsctl signup verify'|cut -d '$' -f2|xargs) && ./$VERIFY_CMD
# if you have this error:  "such file or directory: ./cdsctl signup verify --api-url...",
# you can manually execute the command "./cdsctl signup verify --api-url..."

# run cdsctl
$ ./cdsctl user me

# should returns something like:
#./cdsctl user me
#created   2019-12-18 14:25:53.089718 +0000 UTC
#fullname  admin
#id        vvvvv-dddd-eeee-dddd-fffffffff
#ring      ADMIN
#username  admin

# run others services
$ docker-compose up -d cds-ui cds-cdn cds-hooks cds-elasticsearch cds-hatchery-swarm

# create first worker model
$ ./cdsctl worker model import https://raw.githubusercontent.com/ovh/cds/0.49.0/contrib/worker-models/go-official-1.13.yml

# import Import a workflow template
$ ./cdsctl template push https://raw.githubusercontent.com/ovh/cds/0.49.0/contrib/workflow-templates/demo-workflow-hello-world/demo-workflow-hello-world.yml
Workflow template shared.infra/demo-workflow-hello-world has been created
Template successfully pushed !

# create project, then create a workflow from template
$ ./cdsctl project create DEMO FirstProject
$ ./cdsctl template apply DEMO MyFirstWorkflow shared.infra/demo-workflow-hello-world --force --import-push --quiet

# run CDS Workflow!
$ ./cdsctl workflow run DEMO MyFirstWorkflow
Workflow MyFirstWorkflow #1 has been launched
http://localhost:8080/project/DEMO/workflow/MyFirstWorkflow/run/1