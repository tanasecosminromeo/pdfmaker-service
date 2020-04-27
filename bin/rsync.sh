#!/usr/bin/env bash

####
#### PHPStorm Rsync Deployment Script v0.2-2020.02.13
####
#### This script is useful if you want to quickly download all of the
#### files from a remote server to your local project as fast as you
#### can say rsync :)
####
#### Available commands:
#### ./rsync - This will get all of the changes from deployment server
#### ./rsync deploy - This will upload all local changes to the
####    deployment server
####
#### In combination with PHPStorm Auto Upload feature it should provide
#### a decent remote work experience.
####
#### Limitations:
#### 1. Only works with SFTP web servers that deploy in the home
#### of a user eg: /home/test/blabla. It will NOT work with /mnt/myapp
#### - Will try and remove this limitation in a future server
####
#### 2. Only works with private key auth. This will stay like this
#### but in a future version I'll include a passphrase.
####
#### 3. Currently not working with a mapping other than /
####
#### How it works?
####
#### 1. Configure a PHPStorm Deployment Server. Feel free to configure
#### deployment exclusions paths as these will be taken into account.
#### Tip: Exclude stuff like upload or cache folders. Feel free to leave
#### .git or vendors directory, it will give your IDE extra power
#### 2. In PHPStorm Preferences | Tools | External Tools add an external
#### command to this script, no argument, current working directory and
#### 'Synchronize files after execution'
#### 3. Run the command before you start working and whenever you do
#### external changes like pulling on git.
#### More info still pending
####
####
#### Changelist:
####
#### >> v0.2
#### - Add support for Windows Linux Subsystem - To run you require an ubuntu
#### WSL and a bat script is required to run with PHPStorm. To see how you could
#### implement this using PHPStorm please check https://gitlab.tcrhd.net/snippets/33
#### Note: For this particular script the command needs to be ./rsync.sh %1 instead of the current one
####

# Verify the required packages are installed. They should all be on by default on ubuntu and macOS
if ! [[ -x "$(command -v xmllint)" ]]; then
  echo 'Error: xmllint is not installed.' >&2
  exit 10;
fi

if ! [[ -x "$(command -v cut)" ]]; then
  echo 'Error: cut is not installed.' >&2
  exit 12;
fi

if ! [[ -x "$(command -v rsync)" ]]; then
  echo 'Error: rsync is not installed.' >&2
  exit 13;
fi

if ! [[ -x "$(command -v xargs)" ]]; then
  echo 'Error: xargs is not installed.' >&2
  exit 14;
fi

if ! [[ -x "$(command -v ssh)" ]]; then
  echo 'Error: ssh is not installed.' >&2
  exit 15;
fi

# Mini function to read argument from an XML file
read_xml(){
    #MY_VAR=$(xmllint --xpath "string(//$2)" $1 | xargs) #Unsure why I used xargs before, but this failed on windows
    MY_VAR=$(xmllint --xpath "string(//$2)" $1)
    echo ${MY_VAR}
}

# You may have more than one deployment server, this will be helpful to get the default one
RSYNC_SERVER_NAME=$(read_xml .idea/deployment.xml project/component/@serverName)
if [[ -z "${RSYNC_SERVER_NAME}" ]]
then
    echo You do not have a default deployment server configured
    exit 1;
else
    # Not really required for this script, but in my workflow I want this
    PHPSTORM_AUTO_UPLOAD=$(read_xml .idea/deployment.xml project/component/@autoUpload)

    if [[ "$PHPSTORM_AUTO_UPLOAD" != "Always" ]]
    then
        echo "Tip: You may want to configure PHPStorm to automatically upload your changes"
    fi;

    # Crappy way to get the exclusion path for default deployment server
    deploymentI=0;
    temp="{{not-defined}}";
    while [[ ${deploymentI} -lt 10 && "$temp" != "$RSYNC_SERVER_NAME" ]]
    do
        deploymentI=$[$deploymentI+1]
        temp=$(read_xml .idea/deployment.xml project/component/serverData/paths[${deploymentI}]/@name)
    done;

    if [[ "$temp" != "$RSYNC_SERVER_NAME" ]]
    then
        echo "There is an error while trying to get the details of your default remote server. Please note this script only supports SCP Private key auth!!! Use that!"
        exit 3;
    fi;

    temp="{{not-defined}}";
    excludedPathsI=0
    excludedPathsString=""
    while [[ ${excludedPathsI} -lt 10 && ! -z "${temp}" ]]
    do
        excludedPathsI=$[$excludedPathsI+1]
        temp=$(read_xml .idea/deployment.xml project/component/serverData/paths[${deploymentI}]/serverdata/excludedPaths/excludedPath[${excludedPathsI}]/@path)
        if [[ ! -z "${temp}" ]]
        then
            excludedPathsString="$excludedPathsString --exclude ${temp:1}"
        fi;
    done;

    # Crappy way to get the web server details for default deployment server
    webServerI=0;
    temp="{{not-defined}}";
    while [[ ${webServerI} -lt 10 && "$temp" != "$RSYNC_SERVER_NAME" ]]
    do
        webServerI=$[$webServerI+1]
        temp=$(read_xml .idea/webServers.xml project/component/option/webServer[${webServerI}]/@name)
    done

    if [[ "$temp" != "$RSYNC_SERVER_NAME" ]]
    then
        echo "There is an error while trying to get the details of your default remote server. Please note this script only supports SCP Private key auth!!! Use that!"
        exit 4;
    fi;

    # These are the details we'll need for rsync
    RSYNC_HOST=$(read_xml .idea/webServers.xml project/component/option/webServer[${webServerI}]/fileTransfer/@host)
    RSYNC_PORT=$(read_xml .idea/webServers.xml project/component/option/webServer[${webServerI}]/fileTransfer/@port)
    RSYNC_IDENTITY=$(read_xml .idea/webServers.xml project/component/option/webServer[${webServerI}]/fileTransfer/@privateKey)
    RSYNC_IDENTITY=${RSYNC_IDENTITY/\$USER_HOME\$/~}
    RSYNC_IDENTITY="${RSYNC_IDENTITY//\\//}"

    if [[ ${RSYNC_IDENTITY:1:1} == ":" ]]; then #windows linux subsystem - let's assume a correct one
      # shellcheck disable=SC2001
      DRIVE=$(echo ${RSYNC_IDENTITY:0:1}| sed -e 's/\(.*\)/\L\1/')
      RSYNC_IDENTITY="/mnt/"${DRIVE}${RSYNC_IDENTITY:2}

      chmod 0600 "$RSYNC_IDENTITY"
      chown ${USER}:${USER} "$RSYNC_IDENTITY"
    fi;


    #Todo: Must also get passphrase for people using private keys with passphrase
    RSYNC_ROOT=$(read_xml .idea/webServers.xml project/component/option/webServer[${webServerI}]/fileTransfer/@rootFolder)

    #Todo: Find a way to get this from config. I expect PHPStorm stores this in a separate file
    RSYNC_USER=$(echo ${RSYNC_ROOT} | cut -d/ -f3)

    if [[ $(echo ${RSYNC_ROOT} | cut -d/ -f2) != "home" || -z "${RSYNC_USER}" ]]
    then
        echo "This script can only be used when deploying to /home/user/path";
        exit 5;
    fi;

    # Do the actual rsync. PS: Crucially this will delete local changes hence why I like to have auto upload on
    if [[ "$1" == "deploy" ]]
    then
        echo "Deploy"
        rsync -avz0 -e "ssh -p $RSYNC_PORT -i $RSYNC_IDENTITY" --delete . "$RSYNC_USER@$RSYNC_HOST:$RSYNC_ROOT/" ${excludedPathsString}
    elif [[ "$1" == "" ]]
    then
        echo "Get changes"
        RSYNC_IDENTITY=${RSYNC_IDENTITY:-~/.ssh/id_rsa}
        rsync -avz0 -e "ssh -p $RSYNC_PORT -i $RSYNC_IDENTITY" --delete "$RSYNC_USER@$RSYNC_HOST:$RSYNC_ROOT/" . ${excludedPathsString}
    else
        echo "Invalid command [$1]"
    fi;
    status=$?
    exit ${status}; #We return the actual status of the rsync command so PHPStorm tools will tell us in case we have an error exit code
fi
exit 5;