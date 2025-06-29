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

# Check what type of JAR we have
echo "Checking JAR type and structure..."
if [ -d "/debezium/lib" ]; then
    echo "Found lib/ directory - this is a Quarkus fast-jar"
    echo "Lib directory contents (first 10 files):"
    ls -la /debezium/lib/ | head -10
else
    echo "No lib/ directory found - checking if this is an uber-jar..."
    # Check if the main class is inside the JAR (uber-jar format)
    if jar -tf "$DEBEZIUM_JAR" | grep -q "io/debezium/server/Main.class"; then
        echo "✓ This appears to be an uber-jar (self-contained)"
    else
        echo "✗ Cannot find main class in JAR - this may be a packaging issue"
        echo "Available directories:"
        ls -la /debezium/
        echo "JAR contents (first 20 entries):"
        jar -tf "$DEBEZIUM_JAR" | head -20
        exit 1
    fi
fi

echo "Starting Debezium Server with OpenTelemetry tracing..."
echo "Working directory: $(pwd)"
echo "JAR file: $DEBEZIUM_JAR"

# Check if there's a quarkus-run.jar (proper Quarkus fast-jar)
QUARKUS_RUN_JAR="/debezium/quarkus-app/quarkus-run.jar"
if [ -f "$QUARKUS_RUN_JAR" ]; then
    echo "Found proper Quarkus application structure, using quarkus-run.jar"
    exec java \
        -javaagent:/debezium/otel-javaagent.jar \
        -javaagent:/debezium/jolokia.jar \
        -Dcom.sun.management.jmxremote=true \
        -Dcom.sun.management.jmxremote.authenticate=false \
        -Dcom.sun.management.jmxremote.ssl=false \
        -Dcom.sun.management.jmxremote.port=9012 \
        -Dcom.sun.management.jmxremote.rmi.port=9012 \
        -Djava.rmi.server.hostname=${POD_IP} \
        -jar "$QUARKUS_RUN_JAR" "$@"
else
    echo "Using runner JAR with explicit classpath"
    # For Quarkus fast-jar, we need to build the classpath explicitly
    CLASSPATH="$DEBEZIUM_JAR"
    for jar in /debezium/lib/*.jar; do
        CLASSPATH="$CLASSPATH:$jar"
    done
    
    echo "Running with classpath approach..."
    exec java \
        -javaagent:/debezium/otel-javaagent.jar \
        -javaagent:/debezium/jolokia.jar \
        -Dcom.sun.management.jmxremote=true \
        -Dcom.sun.management.jmxremote.authenticate=false \
        -Dcom.sun.management.jmxremote.ssl=false \
        -Dcom.sun.management.jmxremote.port=9012 \
        -Dcom.sun.management.jmxremote.rmi.port=9012 \
        -Djava.rmi.server.hostname=${POD_IP} \
        -cp "$CLASSPATH" \
        io.debezium.server.Main "$@"
fi