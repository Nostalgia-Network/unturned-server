#!/bin/bash

source .env

NAME_PREFIX="${1:-NOS-UNT-00}"

echo "Starting batch broadcast. Press ^C at any time to cancel..."
echo "Fetching server list..."

# Extract both identifier and name separated by a pipe character
SERVERS=$(curl -s -H "Authorization: Bearer ${PTERODACTYL_API_KEY}" \
    -H "Accept: application/json" \
    "${PTERODACTYL_API}/api/client" | \
    jq -r --arg prefix "$NAME_PREFIX" '.data[] | select(.attributes.name | startswith($prefix)) | "\(.attributes.identifier)|\(.attributes.name)"')

SERVER_IDS=()
SERVER_NAMES=()

for item in $SERVERS; do
    uuid=$(echo "$item" | cut -d '|' -f 1)
    name=$(echo "$item" | cut -d '|' -f 2)
    SERVER_IDS+=("$uuid")
    SERVER_NAMES+=("$name")
done

if [ ${#SERVER_IDS[@]} -eq 0 ]; then
    echo "No servers found starting with '$NAME_PREFIX'. Exiting."
    exit 1
fi

echo "Validating server states..."
VALID_SERVER_IDS=()
VALID_SERVER_NAMES=()

for i in "${!SERVER_IDS[@]}"; do
    uuid="${SERVER_IDS[i]}"
    name="${SERVER_NAMES[i]}"

    # Fetch server resource/status
    state=$(curl -s -H "Authorization: Bearer ${PTERODACTYL_API_KEY}" \
        -H "Accept: application/json" \
        "${PTERODACTYL_API}/api/client/servers/${uuid}/resources" | \
        jq -r '.attributes.current_state')

    if [ "$state" == "offline" ] || [ "$state" == "null" ]; then
        echo "   -> Skipping $name ($uuid) as it is offline/stopped."
    else
        echo " - [Name: $name] (ID: $uuid) - Status: $state"
        VALID_SERVER_IDS+=("$uuid")
        VALID_SERVER_NAMES+=("$name")
    fi
done

SERVER_IDS=("${VALID_SERVER_IDS[@]}")
SERVER_NAMES=("${VALID_SERVER_NAMES[@]}")

if [ ${#SERVER_IDS[@]} -eq 0 ]; then
    echo "No running servers found starting with '$NAME_PREFIX'. Exiting."
    exit 1
fi

send_api_request() {
    local endpoint=$1
    local value=$2
    local server_id=$3

    # Use jq to securely generate the JSON payload, automatically escaping quotes
    local payload
    if [ "$endpoint" == "command" ]; then
        payload=$(jq -n --arg val "$value" '{command: $val}')
    else
        payload=$(jq -n --arg val "$value" '{signal: $val}')
    fi

    local http_status
    local response_body

    http_status=$(curl -s -w "%{http_code}" -o /tmp/pterodactyl_resp.txt -X POST "${PTERODACTYL_API}/api/client/servers/${server_id}/${endpoint}" \
        -H "Authorization: Bearer ${PTERODACTYL_API_KEY}" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$payload")

    response_body=$(cat /tmp/pterodactyl_resp.txt 2>/dev/null)
    rm -f /tmp/pterodactyl_resp.txt

    # Verify if Pterodactyl accepted the command (200, 202, and 204 are success codes)
    if [[ "$http_status" =~ ^20[024]$ ]]; then
        echo "   -> API Success (HTTP $http_status)"
    else
        echo "   -> API Error (HTTP $http_status): $response_body"
    fi
}

broadcast_command() {
    local cmd=$1
    echo "[$(date +%T)] Command: $cmd"
    for i in "${!SERVER_IDS[@]}"; do
        local uuid="${SERVER_IDS[i]}"
        local name="${SERVER_NAMES[i]}"
        echo "   -> Sending to $name ($uuid)..."
        send_api_request "command" "$cmd" "$uuid"
    done
}

broadcast_power() {
    local signal=$1
    echo "[$(date +%T)] Power Signal: $signal"
    for i in "${!SERVER_IDS[@]}"; do
        local uuid="${SERVER_IDS[i]}"
        local name="${SERVER_NAMES[i]}"
        echo "   -> Sending signal to $name ($uuid)..."
        send_api_request "power" "$signal" "$uuid"
    done
}

# Execution logic based on $2
case "$2" in
    "hotfix")
        broadcast_command '/say "Emergency hotfix incoming! The server will perform an unscheduled restart in 3 minutes."'
        echo "[$(date +%T)] Pause: 2 minutes..."
        sleep 120
        broadcast_command '/say "Emergency hotfix incoming! The server will perform an unscheduled restart in 1 minutes."'
        echo "[$(date +%T)] Pause: 55 seconds..."
        sleep 55

        for i in {5..1}; do
            sleep 1
            broadcast_command "/say \"Server restarting in $i...\""
            echo "[$(date +%T)] Pause: 1 second..."
        done

        sleep 1
        broadcast_command '/save'
        broadcast_power 'restart'

        echo "All $NAME_PREFIX servers have been signaled for restart."
        ;;
    "message")
        if [ -n "$3" ]; then
            broadcast_command "/say \"$3\""
        else
            echo "Error: 'message' specified but no message string provided in \$3."
            exit 1
        fi
        ;;
    *)
        # No action should be done
        ;;
esac