# ☁️ Cloudflare DDNS IP Updater - Docker
Lightweight Docker Container that dynamically updates the IP via Cloudflare API. Access your home network remotely via a custom domain name without a static IP! 

## About
This is a fork of [officialEmmel/cloudflare-ddns-updater](https://github.com/officialEmmel/cloudflare-ddns-docker) script added with **docker** support and some **notification services**.
- lightweight docker image based on alpine
- written in pure BASH
- scheduled with crond
- notifications

Pull image from Docker Hub: [zimmermq/cloudflare-ddns](https://hub.docker.com/r/emmello/cloudflare-ddns)

## Configuration
### Example docker-compose.yml
```yaml
services:
  ddns:
    image: emmello/cloudflare-ddns
    restart: always
    container_name: ddns
    environment:
      - CRON_JOB=* * * * *
      - AUTH_EMAIL=mail@example.com
      - AUTH_METHOD=global
      - AUTH_KEY=abcdefgh12345
      - ZONE_IDENTIFIER=123456abcdefgh
      - RECORD_NAME=example.com
      - RECORD_TYPE=A
      - TTL=3600
      - PROXY=true
      - SITENAME=example.com
      - NOTIFICATION_LEVEL=on_success_or_error
      - NTFYURI=https://ntfy.example.com/ddns

```
### Environment variables
### Required
| Name | Description | 
|---|---|
|`AUTH_EMAIL`|(required) Mail used to register with Cloudflare|
|`AUTH_METHOD`|(required) `global` for Global API Key or `token` for Scoped API Token | 
|`ZONE_IDENTIFIER`|(required) Can be found in the "Overview" tab of your domain|
|`RECORD_NAME`|(required) Which record you want to be synced|
|`TTL`|(required) DNS TTL in seconds |`"token":"abc123"`|
|`PROXY`|(required) proxy through cloudflare network `true` or `false`|
|`CRON_JOB`|(required) Array of IPs that cant access the command|

### Notifications
| Name | Description | 
|---|---|
|`SITENAME`|Used for notifications as identifier|
|`NOTIFICATION_LEVEL`|`on_error` to get notified only on error; `on_success_or_error` to get notified on success or error; `always` to get notified oon every try even if ip has not changed| 

#### Slack
| Name | Description | 
|---|---|
|`SLACKURI`|Slack Uri|
|`SLACKCHANNEL`|Slackchannel| 

#### Discord Webhook
| Name | Description | 
|---|---|
|`DISCORDURI`|Discord WebHook uri| 

#### Ntfy
| Name | Description | 
|---|---|
|`NTFYURI`|Ntfy uri and topic| 

#### Telegram
| Name | Description | 
|---|---|
|`TELEGRAM_TOKEN`|Telegram bot token| 
|`TELEGRAM_CHAT_ID`|Telegram chat id| 

### How to use cron
[Cron](https://en.wikipedia.org/wiki/Cron) is used to schedule the script execution.
You can use [crontab.guru](https://crontab.guru) as helper to get the cron job working.
```
# ┌───────────── minute (0 - 59)
# │ ┌───────────── hour (0 - 23)
# │ │ ┌───────────── day of the month (1 - 31)
# │ │ │ ┌───────────── month (1 - 12)
# │ │ │ │ ┌───────────── day of the week (0 - 6) (Sunday to Saturday 7 is also Sunday on some systems)
# │ │ │ │ │                               
# │ │ │ │ │ 
# │ │ │ │ │ 
# * * * * * 
```
