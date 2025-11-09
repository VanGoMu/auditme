#!/bin/bash
# setup.sh - Quick setup script for Debian Monitoring System

set -e

echo "🚀 Setting up Debian Monitoring System..."

# Create directory structure with proper ownership
echo "📁 Creating directory structure..."
mkdir -p fluent-bit grafana/provisioning/datasources grafana/provisioning/dashboards grafana/dashboards

# Create data directories with current user ownership
mkdir -p influxdb-data grafana-data

# Check if .env exists
if [ ! -f .env ]; then
    echo "⚠️  .env file not found."
    if [ -f .env.example ]; then
        echo "📋 Copying .env.example to .env..."
        cp .env.example .env
        echo "⚠️  IMPORTANT: Edit .env and change the default passwords and tokens!"
        echo "   Especially:"
        echo "   - INFLUXDB_ADMIN_PASSWORD"
        echo "   - INFLUXDB_TOKEN"
        echo ""
        echo "Generate a secure token with: openssl rand -base64 32"
        exit 1
    else
        echo "⚠️  .env.example not found either. Please create .env manually."
        exit 1
    fi
fi

# Check if using default credentials
if grep -q "CHANGE_ME" .env; then
    echo "⚠️  WARNING: You are using default credentials in .env!"
    echo "   Please change INFLUXDB_ADMIN_PASSWORD and INFLUXDB_TOKEN"
    read -p "   Continue anyway? (not recommended) [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check if fluent-bit.conf exists
if [ ! -f fluent-bit/fluent-bit.conf ]; then
    echo "⚠️  fluent-bit/fluent-bit.conf not found. Please create it."
    exit 1
fi

# Start services
echo "🐳 Starting Docker services..."
docker compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

echo "📦 InfluxDB buckets will be created automatically when Fluent Bit sends data"

# Check container status
echo "✅ Checking container status..."
docker compose ps

echo ""
echo "✨ Setup complete!"
echo ""
echo "📊 Access points:"
echo "   - Grafana: http://localhost:3000 (admin / GrafanaAdmin123)"
echo "   - InfluxDB: http://localhost:8086 (admin / SecurePassword123)"
echo "   - Fluent Bit metrics: http://localhost:2020/api/v1/metrics"
echo ""
echo "� Pre-configured Grafana Dashboards:"
echo "   - System Monitoring: http://localhost:3000/d/system-monitoring"
echo "   - Network Security: http://localhost:3000/d/network-security"
echo ""
echo "�📝 Next steps:"
echo "   1. Configure iptables logging (see README.md)"
echo "   2. Set up retention policies (see README.md)"
echo "   3. Explore Grafana dashboards"
echo ""
echo "📖 View logs: docker compose logs -f"
