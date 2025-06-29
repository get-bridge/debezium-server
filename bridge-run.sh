#!/bin/bash

export JAVA_OPTS="-javaagent:jolokia.jar -Dcom.sun.management.jmxremote=true -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.port=9012 -Dcom.sun.management.jmxremote.rmi.port=9012 -Djava.rmi.server.hostname=$POD_IP"

if [[ -v PULSAR_SERVICE_ACCOUNT_JSON ]]; then
  echo "$PULSAR_SERVICE_ACCOUNT_JSON" > /tmp/pulsar_creds.json
else
  echo "Pulsar service account environment variable (PULSAR_SERVICE_ACCOUNT_JSON) was not found."
fi

# Change to the correct working directory
cd /debezium

# Find the main runner JAR (Quarkus fast-jar format)
DEBEZIUM_JAR=$(find /debezium -name "*-runner.jar" | head -1)

if [ -z "$DEBEZIUM_JAR" ]; then
    echo "Error: Debezium Server runner JAR not found"
    echo "Looking for available JARs:"
    find /debezium -name "*.jar" -type f
    exit 1
fi

echo "Found Debezium JAR: $DEBEZIUM_JAR"

# Verify the lib directory exists (required for Quarkus fast-jar)
if [ ! -d "/debezium/lib" ]; then
    echo "Error: /debezium/lib directory not found. This is required for Quarkus fast-jar packaging."
    echo "Available directories:"
    ls -la /debezium/
    exit 1
fi

echo "Lib directory contents (first 10 files):"
ls -la /debezium/lib/ | head -10

echo "Starting Debezium Server with OpenTelemetry tracing..."
echo "Working directory: $(pwd)"
echo "JAR file: $DEBEZIUM_JAR"

# Use absolute paths and ensure we're in the correct directory
exec java \
    -javaagent:/debezium/otel-javaagent.jar \
    -javaagent:/debezium/jolokia.jar \
    -Dcom.sun.management.jmxremote=true \
    -Dcom.sun.management.jmxremote.authenticate=false \
    -Dcom.sun.management.jmxremote.ssl=false \
    -Dcom.sun.management.jmxremote.port=9012 \
    -Dcom.sun.management.jmxremote.rmi.port=9012 \
    -Djava.rmi.server.hostname=${POD_IP} \
    -jar "$DEBEZIUM_JAR" "$@"