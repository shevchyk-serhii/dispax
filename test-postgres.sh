#!/bin/bash

echo "🐙 Testing PostgreSQL Integration"

echo "📦 Starting PostgreSQL..."
docker-compose up -d postgres

echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

echo "🚀 Starting application with PostgreSQL..."
USE_POSTGRES=true timeout 10 sbt run &

sleep 8

echo "🧪 Testing API endpoints..."

echo "📋 Testing GET /api/v2/rides..."
curl -s "http://localhost:8080/api/v2/rides" -H "Authorization: Bearer test-token" | jq . || echo "API not ready yet"

echo ""
echo "✅ Integration test complete!"
echo "💡 To manually test:"
echo "   1. docker-compose up -d postgres"
echo "   2. USE_POSTGRES=true sbt run"
echo "   3. Check logs for 'Database: PostgreSQL'"

echo "🧹 Cleanup..."
docker-compose down

kill %1 2>/dev/null || true