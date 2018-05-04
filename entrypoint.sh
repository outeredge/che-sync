#!/bin/bash -e

ssh_args="-o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"
unison_args="-batch -auto -silent -terse -prefer=newer -retry 10 -sshargs '-C ${ssh_args}'"

if [ -t 0 ]; then
    TERM=xterm-256color
    fgRed=$(tput setaf 1)
    fgGreen=$(tput setaf 2)
    fgNormal=$(tput sgr0)
    fgBold=$(tput bold)
else
    echo "ERROR: No TTY found, docker must be run with -t"
    exit 1
fi

echo -e "${fgBold}${fgGreen}                           ";
echo -e "      | |                                     ";
echo -e "   ___| |__   ___       ___ _   _ _ __   ___  ";
echo -e "  / __| '_ \ / _ \_____/ __| | | | '_ \ / __| ";
echo -e " | (__| | | |  __/_____\__ \ |_| | | | | (__  ";
echo -e "  \___|_| |_|\___|     |___/\__, |_| |_|\___| ";
echo -e "                             __/ |            ";
echo -e "                            |___/${fgNormal}\n";

OPTIND=1
while getopts h:u:p:s:t:r: OPT
do
    case "${OPT}"
    in
    h) CHE_HOST=http://${OPTARG};;
    u) CHE_USER=${OPTARG};;
    p) CHE_PASS=${OPTARG};;
    s) SSH_USER=${OPTARG};;
    t) CHE_TOTP=${OPTARG};;
    r) UNISON_REPEAT=${OPTARG};;
    esac
done
shift $((OPTIND - 1))

CHE_WORKSPACE=${1:-$CHE_WORKSPACE}
CHE_PROJECT=${2:-$CHE_PROJECT}

if [[ -z $CHE_HOST || -z $CHE_USER || -z $CHE_PASS || -z $CHE_WORKSPACE || -z $CHE_PROJECT ]]; then
  echo "${fgRed}ERROR: You must specify a host (-h), username (-u), password (-p), workspace and project to continue${fgNormal}"
  exit 1
fi
   
# Authenticate with keycloak and grab tokeb
auth_token_response=$(curl --fail -s -X POST "${CHE_HOST}:5050/auth/realms/che/protocol/openid-connect/token" \
 -H "Content-Type: application/x-www-form-urlencoded" \
 -d "username=${CHE_USER}" \
 -d "password=${CHE_PASS}" \
 -d "totp=${CHE_TOTP}" \
 -d 'grant_type=password' \
 -d 'client_id=che-public') || {
    echo "${fgRed}ERROR: Unable to authenticate with server!${fgNormal}";
    exit 1;
}
auth_token=$(echo $auth_token_response | jq -re '.access_token | select(.!=null)') || {
    echo "${fgRed}ERROR: Unable to authenticate with Che! $(echo $auth_token_response | jq -r '.error_description | select(.!=null)')${fgNormal}";
    exit 1;
}

# Get ssh url from che api
che_ssh=$(curl -s "${CHE_HOST}/api/workspace/${CHE_WORKSPACE}?token=${auth_token}" | jq -re 'first(..|.["dev-machine"]?.servers?.ssh?.url? | select(.!=null))' 2>/dev/null) || {
    echo "${fgRed}ERROR: Unable to obtain SSH connection details for ${CHE_WORKSPACE}, is the workspace running and the SSH agent enabled?${fgNormal}";
    exit 1;
}

# Get ssh key from che api
che_key=$(curl -s "${CHE_HOST}/api/ssh/machine?token=${auth_token}" | jq -re 'first(..|.privateKey? | select(.!=null))' 2>/dev/null) || {
    echo "${fgRed}ERROR: Unable to obtain SSH key for ${CHE_WORKSPACE}, do you have a machine key generated?${fgNormal}";
    exit 1;
}

# Store private key
echo "${che_key}" > $HOME/.ssh/id_rsa
chmod 600 $HOME/.ssh/id_rsa

# Shut down background jobs on exit
trap 'echo "Shutting down sync process..."; kill $(jobs -p) 2> /dev/null; exit' EXIT

# Sync any remote unison profiles first
unison_remote="${che_ssh:0:6}$SSH_USER@${che_ssh:6}//projects/$CHE_PROJECT"
echo "Syncing profiles..."
eval "unison /mount ${unison_remote} ${unison_args} -force ${unison_remote} -path .unison -ignore='Name ?*' -ignorenot='Name *.prf'"
if [ ! -z "$UNISON_PROFILE" ]; then
    echo "Using sync profile ${fgGreen}${fgBold}$UNISON_PROFILE${fgNormal}"
fi

# Run unison sync in the background
echo "Starting background sync process..."
eval "unison ${UNISON_PROFILE} /mount ${unison_remote} ${unison_args} -repeat=${UNISON_REPEAT} \
 -ignore='Name .*'  \
 -ignore='Name *.orig'  \
 -ignore='Name node_modules'" \
> unison.log &

# Drop user into workspace via ssh
echo "Connecting to Che workspace ${fgBold}${fgGreen}$CHE_WORKSPACE${fgNormal} with SSH..."
ssh_connect=${che_ssh:6}
ssh_connect=${ssh_connect/:/ -p}
ssh $ssh_args $SSH_USER@$ssh_connect -t "cd /projects/${CHE_PROJECT}; exec \$SHELL --login"