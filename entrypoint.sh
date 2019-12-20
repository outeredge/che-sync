#!/bin/bash

current_version=3.0.0
#latest_version=$(curl --silent "https://api.github.com/repos/outeredge/che-sync/releases/latest" | jq -r .tag_name)

if [ -t 0 ]; then
    TERM=xterm-256color
    fgRed=$(tput setaf 1)
    fgGreen=$(tput setaf 2)
    fgNormal=$(tput sgr0)
    fgBold=$(tput bold)
else
    echo "ERROR: No TTY found, docker must be run with -it"
    exit 1
fi

echo -e "${fgBold}${fgGreen}                           ";
echo -e "      | |                                     ";
echo -e "   ___| |__   ___       ___ _   _ _ __   ___  ";
echo -e "  / __| '_ \ / _ \_____/ __| | | | '_ \ / __| ";
echo -e " | (__| | | |  __/_____\__ \ |_| | | | | (__  ";
echo -e "  \___|_| |_|\___|     |___/\__, |_| |_|\___| ";
echo -e "                             __/ |            ";
echo -e "                            |___/  ${fgNormal}";
echo -e "${fgGreen} VERSION: ${current_version}${fgNormal}\n";

function version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }
if version_gt $latest_version $current_version; then
     echo -e "${fgRed}You are running an old version of che-sync, please upgrade: ${fgBold}docker pull outeredge/che-sync${fgNormal}"
fi

OPTIND=1
while getopts h:a:u:n:p:s:o:t:r: OPT
do
    case "${OPT}"
    in
    h) CHE_HOST=${OPTARG};;
    a) CHE_AUTH_HOST=${OPTARG};;
    u) CHE_USER=${OPTARG};;
    n) CHE_NAMESPACE=${OPTARG};;
    p) CHE_PASS=${OPTARG};;
    s) SSH_USER=${OPTARG};;
    o) SSH_PORT=${OPTARG};;
    t) CHE_TOTP=${OPTARG};;
    r) UNISON_REPEAT=${OPTARG};;
    esac
done
shift $((OPTIND - 1))

if [[ "$1" == "ssh" && -z "$2" ]]; then
    ssh_only=true
else
    CHE_WORKSPACE=${1:-$CHE_WORKSPACE}
fi

CHE_WORKSPACE=${CHE_NAMESPACE:+$CHE_NAMESPACE/}${CHE_WORKSPACE}
CHE_PROJECT=${2:-$CHE_PROJECT}

if [[ -z "$CHE_HOST" || -z "$CHE_AUTH_HOST" || -z "$SSH_PORT" || -z "$CHE_USER" || -z "$CHE_PASS" || -z "$CHE_WORKSPACE" ]]; then
  echo "${fgRed}ERROR: You must specify at least a host, auth host, ssh port, username, password and workspace to continue${fgNormal}"
  exit 1
fi

# Authenticate with keycloak and grab token
auth_token_response=$(curl --fail -s -X POST "${CHE_AUTH_HOST}/auth/realms/che/protocol/openid-connect/token" \
 -H "Content-Type: application/x-www-form-urlencoded" \
 -d "username=${CHE_USER}" \
 -d "password=${CHE_PASS}" \
 -d "totp=${CHE_TOTP}" \
 -d 'grant_type=password' \
 -d 'client_id=che-public') || {
    echo "${fgRed}ERROR: Unable to authenticate with server!${fgNormal}"
    exit 1
}

auth_token=$(echo $auth_token_response | jq -re '.access_token | select(.!=null)') || {
    echo "${fgRed}ERROR: Unable to authenticate! $(echo $auth_token_response | jq -r '.error_description | select(.!=null)')${fgNormal}"
    exit 1
}

# Get info from che api
che_info=$(curl -s "${CHE_HOST}/api/workspace/${CHE_WORKSPACE}?token=${auth_token}")

che_workspace_id=$(echo $che_info | jq -re '.id | select(.!=null)' 2>/dev/null) || {
    echo "${fgRed}ERROR: Unable to connect to the API for ${CHE_WORKSPACE}${fgNormal}"
    exit 1
}

che_workspace_state=$(echo $che_info | jq -re '.status')

if [ "$che_workspace_state" != "RUNNING" ]; then
    echo "Starting workspace ${CHE_WORKSPACE}";

    curl --fail -s --output /dev/null -X POST "${CHE_HOST}/api/workspace/$che_workspace_id/runtime?token=${auth_token}" || {
        echo "${fgRed}ERROR: Unable to start workspace!${fgNormal}"
        exit 1
    }

    trap "echo Exited!; exit;" SIGINT SIGTERM
    until [ "$(curl -s ${CHE_HOST}/api/workspace/${CHE_WORKSPACE}?token=${auth_token} | jq -re '.status')" == "RUNNING" ]; do
        echo -n '.'
        sleep 1
    done

    echo -e "\nWorkspace successfully started"

    che_info=$(curl -s "${CHE_HOST}/api/workspace/${CHE_WORKSPACE}?token=${auth_token}")
fi

# Get ssh password from workspace
export SSHPASS=$(echo $che_info | jq -re '.devfile?.components[]? | select(.type == "dockerimage").env[]? | select(.name == "SSH_PASSWORD") | .value?' 2>/dev/null) || {
    echo "${fgRed}ERROR: Unable to obtain SSH password for ${CHE_WORKSPACE}, have you enabled SSH in the dockerimage?${fgNormal}"
    exit 1
}

shutdown_handler() {
    echo "Shutting down che-sync...";
    read -p "${fgBold}Stop workspace ${CHE_WORKSPACE} [y/N]?${fgNormal} " answer
    case $answer in
        [yY])
            curl --fail -s --output /dev/null -X DELETE "${CHE_HOST}/api/workspace/$che_workspace_id/runtime?token=${auth_token}" || {
                echo "${fgRed}ERROR: Unable to stop workspace!${fgNormal}"
                exit 1
            }
            echo "Workspace successfully stopped"
            ;;
    esac
    kill 0
}

# Shut down background jobs on exit
trap shutdown_handler EXIT

# Set up SSH commands
if [[ ! -z "$FORWARD_PORT" ]]; then
    host_domain="host.docker.internal"
    ping -q -c1 $host_domain &>/dev/null
    if [ $? -ne 0 ]; then
        host_domain=$(/sbin/ip route|awk '/default/ { print $3 }')
    fi
    ssh_forward ="-R \"*:$FORWARD_PORT:$host_domain:$FORWARD_PORT\""
fi

ssh_host=$(echo $CHE_HOST | awk -F[/:] '{print $4}')
ssh_args="-o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $SSH_PORT"
unison_args="-ui text -batch -auto -silent -terse -confirmbigdel=false -perms 0 -dontchmod -links false -prefer=newer -retry 10 -sshcmd '/sshpass.sh' -sshargs '${ssh_args}'"

if [ "$ssh_only" != true ] ; then
    export UNISONLOCALHOSTNAME=$UNISON_NAME

    echo -e "Starting file sync process..."

    # Run unison sync in the background
    unison_remote="ssh://$SSH_USER@$ssh_host//projects/$CHE_PROJECT"
    eval "unison /mount ${unison_remote} ${unison_args} -repeat=${UNISON_REPEAT} \
    -ignore='Path .unison' \
    -ignore='Path .che' \
    -ignore='Path .idea' \
    -ignore='Path .composer' \
    -ignore='Path .npm' \
    -ignore='Path .config' \
    -ignore='Path docker-compose.yml' \
    -ignore='Path var' \
    -ignore='Path media' \
    -ignore='Path bin' \
    -ignore='Path update' \
    -ignore='Path setup' \
    -ignore='Path dev' \
    -ignore='Path phpserver' \
    -ignore='Path generated' \
    -ignore='Path pub/media' \
    -ignore='Path pub/static' \
    -ignore='Name .git' \
    -ignore='Name *.orig' \
    -ignore='Name *.sql' \
    -ignore='Name .DS_Store' \
    -ignore='Name node_modules' \
    -ignorenot='Path var/log ' \
    -ignorenot='Path var/report ' \
    " &
fi

# Drop user into workspace via ssh
echo "Connecting to workspace ${fgBold}${fgGreen}$CHE_WORKSPACE${fgNormal} with SSH..."
eval "/sshpass.sh $ssh_args $ssh_forward $SSH_USER@$ssh_host -t \"cd /projects/${CHE_PROJECT}; bash --rcfile ~/.bashrc\""