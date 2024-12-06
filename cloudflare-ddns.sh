#!/bin/bash

# the cf ddns script by K0p1-Git modified with some notification options and dockerized by me
# https://github.com/K0p1-Git/cloudflare-ddns-updater

#env vars
auth_email="${AUTH_EMAIL}"                   # The email used to login 'https://dash.cloudflare.com'
auth_method="${AUTH_METHOD}"                 # Set to "global" for Global API Key or "token" for Scoped API Token
auth_key="${AUTH_KEY}"                       # Your API Token or Global API Key
zone_identifier="${ZONE_IDENTIFIER}"         # Can be found in the "Overview" tab of your domain
record_name="${RECORD_NAME}"                 # Which record you want to be synced
ttl="${TTL}"                                 # Set the TTL (Time to Live) for the record, min value 120
proxy="${PROXY}"                             # Set the proxy status, true or false

sitename="${SITENAME}"                       # The name of the site
notification_level="${NOTIFICATION_LEVEL}"   # The level of notification to send. Options: always, on_success_or_error, on_error
slackuri="${SLACKURI}"                       # URI for Slack WebHook "https://hooks.slack.com/services/xxxxx"
slackchannel="${SLACKCHANNEL}"               # The channel to send slack notifications to
discorduri="${DISCORDURI}"                   # URI for Discord WebHook "https://discordapp.com/api/webhooks/xxxxx"
ntfyuri="${NTFYURI}"
telegram_token="${TELEGRAM_TOKEN}"
telegram_chat_id="${TELEGRAM_CHAT_ID}"

err() {
  echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log() {
  echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"
}

send_notification() {

  if [[ -n $slackuri ]]; then
    log "Sending notification to slack"
    curl --silent -o /dev/null  -L -X POST $slackuri \
    --data-raw '{
      "channel": "'$slackchannel'",
      "text" : "'"$1"'"
    }'
  fi
  if [[ -n $discorduri  ]]; then
    log "Sending notification to discord"
    curl --silent -o /dev/null  -i -H "Accept: application/json" -H "Content-Type:application/json" -X POST \
    --data-raw '{
      "content" : "'"$1"'"
    }' $discorduri

  fi
  if [[ -n $ntfyuri ]]; then
    log "Sending notification to ntfy"
    curl --silent -o /dev/null -d "$(echo $1)" $ntfyuri
  fi
  if [[ -n $telegram_token ]] && [[ -n $telegram_chat_id ]]; then
    log "Sending notification to telegram"
    curl --silent -o /dev/null  -H 'Content-Type: application/json' -X POST \
    --data-raw '{
      "chat_id": "'$telegram_chat_id'", "text": "'"$1"'"
    }' https://api.telegram.org/bot$telegram_token/sendMessage
  fi
}

notify() {
  if [[ $notification_level == "always" ]]; then
    send_notification "$(echo $2)"
  elif [[ $notification_level == "on_success_or_error" ]]; then
    if [[ $1 == "success" ]] || [[ $1 == "error" ]]; then
      send_notification "$(echo $2)"
    fi
  elif [[ $notification_level == "on_error" ]]; then
    if [[ $1 == "error" ]]; then
      send_notification "$(echo $2)"
    fi
  fi
}

###########################################
## Check if we have a public IP
###########################################
ipv4_regex='([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])\.([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])'
ip=$(curl -s -4 https://cloudflare.com/cdn-cgi/trace | grep -E '^ip'); ret=$?
if [[ ! $ret == 0 ]]; then # In the case that cloudflare failed to return an ip.
    # Attempt to get the ip from other websites.
    ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
else
    # Extract just the ip from the ip line from cloudflare.
    ip=$(echo $ip | sed -E "s/^ip=($ipv4_regex)$/\1/")
fi

# Use regex to check for proper IPv4 format.
if [[ ! $ip =~ ^$ipv4_regex$ ]]; then
    err "Failed to find valid IP"
    notify "error" "DDNS Update Failed: Failed to find valid IP"
    exit 2
fi

###########################################
## Check and set the proper auth header
###########################################
if [[ "${auth_method}" == "global" ]]; then
  auth_header="X-Auth-Key:"
else
  auth_header="Authorization: Bearer"
fi

###########################################
## Seek for the A record
###########################################

log "Check initiated"
record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?type=A&name=$record_name" \
                      -H "X-Auth-Email: $auth_email" \
                      -H "$auth_header $auth_key" \
                      -H "Content-Type: application/json")

###########################################
## Check if the domain has an A record
###########################################
if [[ $record == *"\"count\":0"* ]]; then
  err "Record does not exist, perhaps create one first? (${ip} for ${record_name})"
  notify "error" "DDNS Update Failed: Record does not exist, perhaps create one first? (${ip} for ${record_name})"
  exit 1
fi

###########################################
## Get existing IP
###########################################
old_ip=$(echo "$record" | sed -E 's/.*"content":"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/')
# Compare if they're the same
if [[ $ip == $old_ip ]]; then
  log "Update skipped because IP ($ip) for ${record_name} has not changed."
  notify "debug" "DDNS-Update Skipped: IP ($ip) for ${record_name} has not changed."
  exit 0
fi

###########################################
## Set the record identifier from result
###########################################
record_identifier=$(echo "$record" | sed -E 's/.*"id":"([A-Za-z0-9_]+)".*/\1/')

###########################################
## Change the IP@Cloudflare using the API
###########################################
update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
                     -H "X-Auth-Email: $auth_email" \
                     -H "$auth_header $auth_key" \
                     -H "Content-Type: application/json" \
                     --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\",\"ttl\":$ttl,\"proxied\":${proxy}}")

###########################################
## Report the status
###########################################
case "$update" in
*"\"success\":false"*)
  err "$ip $record_name DDNS failed for $record_identifier ($ip). DUMPING RESULTS:\n$update"
  notify "error" "'"$sitename"' DDNS Update Failed: '$record_name': '$record_identifier' ('$ip')."
  exit 1;;
*)
  log "$ip $record_name DDNS updated."
  notify "success" "'"$sitename"'" Updated: '$record_name''"'"'s'""' new IP Address is '$ip'"
  exit 0;;
esac
