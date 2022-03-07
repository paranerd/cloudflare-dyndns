# General variables
api_url="https://api.cloudflare.com/client/v4"
config_location="./cloudflare.ini"
logger_prefix="DynDNS Updater:"

# Extract sections from config
sections=$(sed -n -e 's/^\[\(.*\)\]/\1/p' $config_location)

logger_info() {
  echo $logger_prefix $1
}

logger_error() {
  echo $logger_prefix $1 >&2
}

determine_auth_header() {
  if [ "$1" == "global" ]; then
    echo "X-Auth-Key: $2"
  else
    echo "Authorization: Bearer $2"
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
  echo EMAIL: $3
  record=$(curl -s -X GET "$api_url/zones/$1/dns_records?name=$2&type=A" \
  -H "X-Auth-Email: $3" \
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

parseini() {
  local section=$1
  local key=$2

  # https://stackoverflow.com/questions/49399984/parsing-ini-file-in-bash
  # This awk line turns ini sections => [section-name]key=value
  local lines=$(awk '/\[/{prefix=$0; next} $1{print prefix $0}' $config_location)

  # Search for key in section
  for line in $lines; do
    if [[ "$line" = \[$section\]* ]]; then
      local keyval=$(echo $line | sed -e "s/^\[$section\]//")
      if [[ -z "$key" ]]; then
        echo $keyval
      elif [[ "$keyval" = $key=* ]]; then
        echo $(echo $keyval | sed -e "s/^$key=//")
      fi
    fi
  done
}

logger_info "Starting DynDNS update..."

# Loop through every section
for section in $sections
do
  # Read config
  auth_method=$(parseini $section AUTH_METHOD)
  api_key=$(parseini $section API_KEY)
  zone_id=$(parseini $section ZONE_ID)
  record_name=$(parseini $section RECORD_NAME)
  email=$(parseini $section EMAIL)

  # Determine authentication header
  auth_header=$(determine_auth_header $auth_method $api_key)

  # Get A record
  record=$(get_record $zone_id $record_name $email)

  current_ip=$(get_current_ip)
  previous_ip=$(get_previous_ip $record)

  # Check if IP changed
  if [[ $current_ip == $previous_ip ]]; then
    logger_info "IP ($current_ip) for ${record_name} unchanged."
    continue
  fi

  # Extract record ID
  record_id=$(get_record_id ${record})

  # Update IP
  update_dns_record $record_id $current_ip
done
