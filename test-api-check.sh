#!/bin/bash

echo "🚀 Starting API server in background..."
sbt run &
API_PID=$!

echo "⏳ Waiting for server to start..."
sleep 8

echo "🥒 Running Cucumber health check test..."
sbt "testOnly *CucumberRunner -- --tags @api"

echo "🛑 Stopping API server..."
kill $API_PID 2>/dev/null

echo "✅ Test completed!"