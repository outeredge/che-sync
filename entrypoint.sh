#!/bin/bash

CHE_DIRECTORY=""
CHE_WORKSPACE=""
CHE_HOSTNAME=""
CHE_USERNAME=""
CHE_PASSWORD=""
SSH_USER="user"

OPTIND=1
while getopts h:u:p:s: OPT
do
    case "${OPT}"
    in
    h) CHE_HOSTNAME=${OPTARG};;
    u) CHE_USERNAME=${OPTARG};;
    p) CHE_PASSWORD=${OPTARG};;
    s) SSH_USER=${OPTARG};;
    esac
done
shift $((OPTIND - 1))

if [[ -z $CHE_HOSTNAME || -z $CHE_USERNAME || -z $CHE_PASSWORD ]]; then
  echo 'ERROR: You must specify a host (-h), username (-u) and password (-p) to continue'
  exit 1
fi

CHE_WORKSPACE=${1?No workspace specified}
CHE_DIRECTORY=${2?No remote path specified}

UNISON_PATH="/mount"
UNISON_SYNC_PERIOD=5
UNISON_ARGS="-batch -auto -prefer=newer -sshargs '-C -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no'"

AUTH_TOKEN_RESPONSE=$(curl --fail -s -X POST "${CHE_HOSTNAME}:5050/auth/realms/che/protocol/openid-connect/token" \
 -H "Content-Type: application/x-www-form-urlencoded" \
 -d "username=${CHE_USERNAME}" \
 -d "password=${CHE_PASSWORD}" \
 -d 'grant_type=password' \
 -d 'client_id=che-public') || {
    echo "ERROR: Unable to connect to Keycloak server!";
    exit 1;
}

AUTH_TOKEN=$(echo $AUTH_TOKEN_RESPONSE | jq -re '.access_token | select(.!=null)') || {
    echo "ERROR: Unable to authenticate with Che! $(echo $AUTH_TOKEN_RESPONSE | jq -r '.error_description | select(.!=null)')";
    exit 1;
}

CHE_SSH=$(curl -s "${CHE_HOSTNAME}/api/workspace/${CHE_WORKSPACE}?token=${AUTH_TOKEN}" | jq -re 'first(..|.["dev-machine"]?.servers?.ssh?.url? | select(.!=null))' 2>/dev/null) || {
    echo "ERROR: Unable to obtain SSH connection details for ${CHE_WORKSPACE}, is the workspace running and the SSH agent enabled?"; 
    exit 1; 
}

CHE_KEY=$(curl -s "${CHE_HOSTNAME}/api/ssh/machine?token=${AUTH_TOKEN}" | jq -re 'first(..|.privateKey? | select(.!=null))' 2>/dev/null) || {
    echo "ERROR: Unable to obtain SSH key for ${CHE_WORKSPACE}, do you have a machine key generated?"; 
    exit 1; 
}

CHE_DIRECTORY="${CHE_SSH:0:6}$SSH_USER@${CHE_SSH:6}/$CHE_DIRECTORY"

# Store private key
echo "${CHE_KEY}" > $HOME/.ssh/id_rsa
chmod 600 $HOME/.ssh/id_rsa

# Only sync the .unison folder
UNISON_COMMAND="unison ${UNISON_PATH} ${CHE_DIRECTORY} -path .unison ${UNISON_ARGS}"
eval "${UNISON_COMMAND}"

if [ -f $UNISON_PATH/.unison/default.prf ]; then
    echo "INFO: Found unison profile, setting as default"
    cp -rf $UNISON_PATH/.unison/default.prf $HOME/.unison/default.prf
fi

# Run an initial sync
UNISON_COMMAND="unison ${UNISON_PATH} ${CHE_DIRECTORY} ${UNISON_ARGS}"
eval "${UNISON_COMMAND}"

status=$?
if [ $status -ne 0 ]; then
    echo "ERROR: Fatal error occurred ($status)"
    exit 1
fi

# Run the background sync
echo "INFO: Background syncing every ${UNISON_SYNC_PERIOD} seconds."
UNISON_COMMAND="unison ${UNISON_PATH} ${CHE_DIRECTORY} ${UNISON_ARGS} -retry 10 -copyonconflict -repeat=${UNISON_SYNC_PERIOD}"
eval "${UNISON_COMMAND}"
