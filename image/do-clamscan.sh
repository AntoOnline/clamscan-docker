#!/bin/bash

send_slack_notification() {
    local SLACK_WEB_HOOK="$1"
    local slack_message="$2"

    if [[ -n "$SLACK_WEB_HOOK" ]]; then
        curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"$slack_message\"}" "$SLACK_WEB_HOOK"
    fi
}

mkdir -p ${FOLDER_TO_SCAN}


# copy not scanned files to tmp directory then scan it !
LAST_SCANNED_FILE=/tmp/clamscan-last-scanned-file
if [ ! -f ${LAST_SCANNED_FILE} ]; then
  touch --date "2000-01-01" ${LAST_SCANNED_FILE}
fi
rm -rf /tmp/new-files-to-scan/
mkdir -p /tmp/new-files-to-scan/
if [ "${SCAN_ONLY_NEW_FILES}" == "1" ]; then
  rsync -a \
    --files-from=<(find ${FOLDER_TO_SCAN} -newer ${LAST_SCANNED_FILE} -type f -exec ls {} \; | sed "s#${FOLDER_TO_SCAN}##g") \
    ${FOLDER_TO_SCAN} \
    /tmp/new-files-to-scan
else
  rsync -a ${FOLDER_TO_SCAN} /tmp/new-files-to-scan
fi

if [ "$(ls /tmp/new-files-to-scan/)" == "" ]; then
  echo "-> Nothing new to scan in ${FOLDER_TO_SCAN}, skipping"
  exit 0
fi

echo "-> Scanning $(find /tmp/new-files-to-scan/ -type f | wc -l) (new) files from ${FOLDER_TO_SCAN} mounted docker volume"
clamscan $CLAMSCAN_OPTIONS /tmp/new-files-to-scan/ | tee /tmp/clamscan.log

grep "Infected files: 0" /tmp/clamscan.log >/dev/null
SOMETHING_IS_INFECTED=$?
if [ "$SOMETHING_IS_INFECTED" != "0" ]; then
  if [ "$(grep '[^[:space:]]' /tmp/clamscan.log)" != "" ]; then
    if [ "$SMTP_HOST" != "" ]; then
      echo "-> Infected: send an alert email to ${ALERT_MAILTO}"
      echo "To: ${ALERT_MAILTO}
From: noreply@${SMTP_MAILDOMAIN}
Subject: ${ALERT_SUBJECT}

$(cat /tmp/clamscan.log)" \
      | msmtp ${ALERT_MAILTO}
    elif [ "$SLACK_WEB_HOOK" != "" ]; then
      echo "-> Infected: send an alert to Slack"
      slack_message="Alert: Something is infected! Check the log: $(cat /tmp/clamscan.log)"
      send_slack_notification "${SLACK_WEB_HOOK}" "${slack_message}"
    else
      echo "-> Infected: but no alert sent as neither SMTP_HOST nor SLACK_WEB_HOOK is provided"
    fi
  fi
fi

# get the last modified file and copy it as a date flag for the next scan
cp -af \
  "$(find ${FOLDER_TO_SCAN} -type f -exec stat --format '%Y %n' "{}" \; | sort -nr | cut -d' ' -f2- | head -1)" \
  ${LAST_SCANNED_FILE}
