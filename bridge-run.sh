#!/bin/bash

export JAVA_OPTS="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -javaagent:jolokia.jar"

if [[ -v PULSAR_SERVICE_ACCOUNT_JSON ]]; then
  echo "$PULSAR_SERVICE_ACCOUNT_JSON" > /tmp/pulsar_creds.json
else
  echo "Pulsar service account environment variable (PULSAR_SERVICE_ACCOUNT_JSON) was not found."
fi

/debezium/run.sh