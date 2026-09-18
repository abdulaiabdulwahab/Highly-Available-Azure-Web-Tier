#!/bin/bash

URL="$1"

if [ -z "$URL" ]; then
    echo "Usage: ./test-endpoint.sh <URL>"
    exit 1
fi

echo "Testing application endpoint..."

for i in {1..10}; do
    curl -s "$URL"
    echo
done

# This script tests the application endpoint by sending 10 HTTP GET requests to the specified URL using curl. It takes the URL as an argument and prints the response for each request. If no URL is provided, it displays usage instructions and exits.