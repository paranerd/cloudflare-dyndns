#!/bin/bash

zone_id="" # Get the zone ID from the overview page
record_name="" # Record name to be updated
auth_method="token" # Use "global" for Global API Key or "token" for API Token (recommended)
email="" # Only required for Global API Key authentication
api_key=""

api_url="https://api.cloudflare.com/client/v4"
config_location="./dyndns.conf"
logger_prefix="DynDNS Updater:"

email_config=$(grep -Pos '(?<=EMAIL=)[^\s]*' ${config_location})
api_key_config=$(grep -Pos '(?<=API_KEY=)[^\s]*' ${config_location})
zone_id_config=$(grep -Pos '(?<=ZONE_ID=)[^\s]*' ${config_location})
record_name_config=$(grep -Pos '(?<=RECORD_NAME=)[^\s]*' ${config_location})
auth_method_config=$(grep -Pos '(?<=AUTH_METHOD=)[^\s]*' ${config_location})

email=${email:-$email_config}
api_key=${api_key:-$api_key_config}
zone_id=${zone_id:-$zone_id_config}
record_name=${record_name:-$record_name_config}
auth_method=${auth_method:-$auth_method_config}

logger_info() {
  echo $logger_prefix $1
}

logger_error() {
  echo $logger_prefix $1 >&2
}

determine_auth_header() {
  if [ "${auth_method}" == "global" ]; then
    echo "X-Auth-Key: ${api_key}"
  else
    echo "Authorization: Bearer ${api_key}"
  fi
}

get_current_ip() {
  # Fetch public IP
  ip_url="https://ipv4.icanhazip.com"

  # Store the whole response with the status at the and
  ip_response=$(curl -s4w "HTTPSTATUS:%{http_code}" $ip_url)

  # Extract the body
  ip_body=$(echo $ip_response | sed -e 's/HTTPSTATUS\:.*//g')

  # Extract the status
  ip_status=$(echo $ip_response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

  if [ ! $ip_status -eq 200 ]; then
    logger_error "Error obtaining public IP [HTTP status: $ip_status]"
    exit 1
  fi

  # Trim whitespace
  ip="$(echo -e "${ip_body}" | tr -d '[:space:]')"

  # Check if we have an IP
  if [ "${ip}" == "" ]; then
    exit 1
  fi

  echo $ip
}

get_record() {
  record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$record_name&type=A" \
  -H "X-Auth-Email: $email" \
  -H "${auth_header}" \
  -H "Content-Type: application/json")

  # Check if there is an A record
  if [[ $record == *"\"count\":0"* ]]; then
    logger_error "DynDNS Updater: No A record present"
    exit 1
  fi

  echo $record
}

get_previous_ip() {
  previous_ip=$(echo "$record" | grep -Po '(?<="content":")[^"]*' | head -1)

  echo $previous_ip
}

get_record_id() {
  record_id=$(echo "$record" | grep -Po '(?<="id":")[^"]*' | head -1)

  echo $record_id
}

update_dns_record() {
  # Update DNS
  update_response=$(curl -X PATCH --write-out "HTTPSTATUS:%{http_code}" "${api_url}/zones/${zone_id}/dns_records/$1" \
  -H "X-Auth-Email: ${email}" \
  -H "${auth_header}" \
  -H "Content-Type: application/json" \
  --data '{"type":"A","name":"'${record_name}'","content":"'${2}'"}')

  # Extract the body
  update_body=$(echo $update_response | sed -e 's/HTTPSTATUS\:.*//g')

  # Extract the status
  update_status=$(echo $update_response | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

  # Check if successful
  if [ ! $update_status -eq 200 ]; then
    logger_error "Error updating IP: ${update_status} | ${update_body}"
    exit 1
  fi
}

logger_info "Starting DynDNS update..."

# Determine authentication header
auth_header=$(determine_auth_header)

# Get A record
record=$(get_record)

current_ip=$(get_current_ip)
previous_ip=$(get_previous_ip $record)

# Check if IP changed
if [[ $current_ip == $previous_ip ]]; then
  logger_info "IP ($current_ip) for ${record_name} unchanged."
  exit 0
fi

# Extract record ID
record_id=$(get_record_id ${record})

# Update IP
update_dns_record $record_id $current_ip

logger_info "IP successfully updated."
