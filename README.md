# clamscan-docker

This Docker container will use [ClamAV](https://www.clamav.net/) ClamAV to scan a mounter folder for viruses and send an email or Slack message if a virus is found.

You can get the container to scan at startup and then on a cron schedule. It will only scan new files on the cron schedule.

Please check out the original source from: abes-esr/clamscan-docker. This is a fork of that project. I have only added Slack and use the latest Ubuntu image.

Note: I have not tested the email functionality. I have only tested the Slack functionality. Please use abes-esr/clamscan-docker if you need email functionality.

## Parameters

- `SCAN_AT_STARTUP`: if 1, then start with a scan when the container is created (default is `1`)
- `FRESHCLAM_AT_STARTUP`: if 1, then update the virus database when the container startup (default is `1`)
- `SCAN_ONLY_NEW_FILES`: if 1, then the scan will scan a first time the whole `FOLDER_TO_SCAN` content, and the next time (see `CRON_CLAMSCAN`) it will only scan the new files found. Thanks to this feature, the process will be lighter (less CPU usage) especially when there is lot and lot of files in `FOLDER_TO_SCAN` (default is `1`)
- `FOLDER_TO_SCAN`: this is the folder to scan with clamscan (default is `/folder-to-scan/`)
- `CRON_CLAMSCAN`: crontab parameters to run the clamscan command which is used to scan the `FOLDER_TO_SCAN` (default is `*/5 * * * *` - it means each 5 minutes)
- `CRON_FRESHCLAM`: crontab parameters to run the freshclam command which is used to update virus databases (default is `0 * * * * *` - it means each hours)
- `ALERT_MAILTO`: email address to send the alerts to (empty value as default so nothing is sent as)
- `ALERT_SUBJECT`: email subject for sending alerts to (`Alert from clamscan !` is the default value)
- `SMTP_TLS`: to enable TLS, set the value to `on` (default is `off`)
- `SMTP_HOST`: host or ip of the smtp server used to send the alerts (default is `127.0.0.1`)
- `SMTP_PORT`: port of the smtp server used to send the alerts (default is` 25`)
- `SMTP_USER`: smtp server login (empty value as default)
- `SMTP_PASSWORD`: smtp server password (empty value as default)
- `SLACK_WEB_HOOK`: the slack web hook url to send a message too.

## Usage

Here is a basic usecase for sending email:

You have a folder (`/var/www/html/uploads/`) where anonymous users can upload attachment thanks to a web form. You want to be sure there is no malicious uploaded files. So you decide to deploy `clamscan-docker` to scan this folder each 15 minutes and to be alerted to `mymail@mydomain.fr` if a virus is uploaded. Here is the docker commande you will run:

```
docker run -d --name myclamavcontainer \
  -v /var/www/html/uploads/:/folder-to-scan/ \
  -e SCAN_AT_STARTUP="1"
  -e CRON_CLAMSCAN="*/15 * * * *" \
  -e ALERT_SUBJECT="Alert from clamscan !" \
  -e ALERT_MAILTO="mymail@mydomain.fr" \
  -e SMTP_HOST="smtp.mydomain.fr" \
  -e SMTP_PORT="25" \
  antoonline/clamscan-docker:latest
```

Or using docker-compose:

```
version: '3'

services:
  clamav:
    build: ./image/
    image: antoonline/clamscan-docker:latest
    container_name: clamav
    environment:
      FRESHCLAM_AT_STARTUP: "1"
      SCAN_AT_STARTUP: "1"
      SCAN_ONLY_NEW_FILES: "1"
      FOLDER_TO_SCAN: "/folder-to-scan/"
      CRON_CLAMSCAN: "0 * * * *"
      CLAMSCAN_OPTIONS: "--recursive=yes --allmatch=yes --remove=no --suppress-ok-results"
    depends_on:
      - clamav-mailhog
    volumes:
      - /path/to/scan/:/folder-to-scan/

  clamav-mailhog:
    image: mailhog/mailhog:v1.0.1
    container_name: clamav-mailhog
    environment:
      MH_SMTP_BIND_ADDR: "0.0.0.0:1025" # cf https://github.com/mailhog/MailHog/blob/master/docs/CONFIG.md
    ports:
      - 8025:8025
    logging:
      driver: none
```

Here is a basic usecase for sending to slack:

```
docker run -d --name myclamavcontainer \
  -v /var/www/html/uploads/:/folder-to-scan/ \
  -e SCAN_AT_STARTUP="1"
  -e CRON_CLAMSCAN="*/15 * * * *" \
  -e SLACK_WEB_HOOK="https://hooks.slack.com/services/.../.../...." \
  antoonline/clamscan-docker:latest
```

Or using docker compose:

```
version: '3'

services:
  clamav:
    build: ./image/
    image: antoonline/clamscan-docker:latest
    container_name: clamav
    environment:
      FRESHCLAM_AT_STARTUP: "1"
      SCAN_AT_STARTUP: "1"
      SCAN_ONLY_NEW_FILES: "1"
      FOLDER_TO_SCAN: "/folder-to-scan/"
      CRON_CLAMSCAN: "0 * * * *"
      CLAMSCAN_OPTIONS: "--recursive=yes --allmatch=yes --remove=no --suppress-ok-results"
      SLACK_WEB_HOOK: "https://hooks.slack.com/services/.../.../...."
    volumes:
      - /path/to/scan/:/folder-to-scan/
```

## Debugging and testing

Firstly, download a virus and put it into `./volumes/folder-to-scan/`:

```
cd ./clamscan-docker/
mkdir -p volumes/folder-to-scan/ && cd volumes/folder-to-scan/
curl -L "https://github.com/ytisf/theZoo/blob/dd88d539de6c91e39483848fa0bd2fe859009c3e/malware/Binaries/Win32.LuckyCat/Win32.LuckyCat.zip?raw=true" > ./Win32.LuckyCat.zip
unzip -P infected ./Win32.LuckyCat.zip
```

Then run the run the docker container to test.

## See also
- https://github.com/abes-esr/clamscan-docker
- https://dev.to/brisbanewebdeveloper/scan-infected-files-with-docker-and-clam-antivirus-clamav-1939
- https://medium.com/@darkcl_dev/scanning-files-with-clamav-inside-a-dockerized-node-application-bd2e5fcc5ce8

