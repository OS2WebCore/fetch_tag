#!/bin/bash
DATE=`date +%Y%m%d%H%M`
SCRIPT_PATH="`dirname \"$0\"`"
SCRIPT_PATH="`( cd \"$SCRIPT_PATH\" && pwd )`"


# Referencing undefined variables (which default to "")
set -o nounset
# Don't ignore failed commands
set -o errexit
# This setting prevents errors in a pipeline from being masked
set -o pipefail
# Strict IFS for loops with spaces
IFS=$'\n\t'

COLOR_OFF="\e[0;39m"
RED="\e[0;31m"
GREEN="\e[1;32m"
YELLOW="\e[0;33m"
MAGENTA="\e[0;35m"
CYAN="\e[0;36m"
DARK_GRAY="\e[90m"
BLINK="\e[5m"

function debug()
{
  echo -e "${DARK_GRAY}${1}${COLOR_OFF}";
}

function error()
{
  echo -e "${RED}${1}${COLOR_OFF}"
}

function notice()
{
  echo -e "${YELLOW}${1}${COLOR_OFF}"
}

function success()
{
  echo -e "${GREEN}${1}${COLOR_OFF}"
}

function blink()
{
  echo -e "${BLINK}${1}${COLOR_OFF}"
}

if [[ -z "${1+present}" ]]; then
  error "Missing argument, specify tag you want to checkout"
  exit;
fi

TAG=$1
RESTORE=false

if [[ $1 == "restore" ]]; then
  if [[ -z "${2+present}" ]]; then
    error "Missing argument, specify tag you want to checkout"
    exit;
  fi
  TAG=$2
  RESTORE=true
fi

if [[ $RESTORE == true ]]; then
  notice "This will checkout tag $TAG, and restore database from info-file $SCRIPT_PATH/$TAG.info"

  if [[ ! -f $SCRIPT_PATH/$TAG.info ]]; then
    error "No info file was found for the tag, no database backup info available. The specified tag will still be checked out."
  else
    BACKUP_PATH=`cat $SCRIPT_PATH/$TAG.info`
    debug "Path to database backup: $BACKUP_PATH"
  fi
fi

# A guess of where document root can be, relative to the script
# pwd.
PRE=".
..
./public_html
../public_html"

CURRENT_DIR=`pwd`

#
# Establish document root for the project.
#
debug "Establish document root."
for i in $PRE; do
  TEST_DIR=$(readlink -f $CURRENT_DIR/$i)

  if [[ -d $TEST_DIR ]]; then

    RES=`cd $TEST_DIR; drush status drupal-version`
    if [[ $RES != "" ]]; then
      DOCUMENT_ROOT=$TEST_DIR
      break
    fi
  fi
done

if [[ $DOCUMENT_ROOT == "" ]]; then
  error "Could not establish document root"
  exit;
fi

debug "Seems to be '$DOCUMENT_ROOT'."

#
# Check if repo is clean.
#
debug "Check status of repo."
GIT_STATUS=$(cd $DOCUMENT_ROOT; git diff --shortstat 2> /dev/null | tail -n1)

if [[ $GIT_STATUS != "" ]]; then
  error "There are uncommitted changes in the repo, clean up before proceeding."
  exit;
fi

debug "Repo status seems alright."

#
# Check if the tag is available.
#
CONTINUE=
for available in `cd $DOCUMENT_ROOT; git tag`; do
  if [[ $available == $TAG ]]; then
    CONTINUE=y
  fi
done

if [ "$CONTINUE" != "y" ]; then
  notice "The specified tag is not avaialble"
  exit
fi

CURRENT_TAG=`cd $DOCUMENT_ROOT; git describe --tags`
if [[ $TAG == $CURRENT_TAG ]]; then
  notice "The specified tag is already chekced out"
  exit;
fi

notice "Current tag is $CURRENT_TAG, this will change to $TAG, continue (y/N)"

read CONTINUE
if [ "$CONTINUE" != "y" ]; then
  exit
fi

if [[ $RESTORE != true ]]; then
  debug "Backup database."
  cd $DOCUMENT_ROOT; git fetch --tags
  cd $DOCUMENT_ROOT; drush sql-dump | gzip > $HOME/backup_$DATE.sql.gz
  echo "Created database backup $HOME/backup_$DATE.sql.gz"
  echo "path saved in: $SCRIPT_PATH/$CURRENT_TAG.info"
  # Save info about what db was used with the current tag.
  echo "$HOME/backup_$DATE.sql.gz" > $SCRIPT_PATH/$CURRENT_TAG.info
fi

RES=`cd $DOCUMENT_ROOT; git checkout --quiet $TAG`

if [[ $RES != "" ]]; then
  echo $RES
else
  success "Checkout successful"
fi

if [[ $RESTORE == true ]]; then
  debug "Restore database from backup."
  if [[ -z "${BACKUP_PATH+present}" ]]; then
    exit
  fi

  RES=`cd $DOCUMENT_ROOT; gunzip -c $BACKUP_PATH | drush sql-cli`
  echo $RES
fi
