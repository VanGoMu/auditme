# Systemd Service for Auditme

This directory contains systemd service files to run the Auditme monitoring stack automatically on system boot.

The `setup.sh` must be launched before service instalation to ensure all requierments are installed.

## How It Works

The service uses **environment variable substitution** via `envsubst` to automatically configure the project path:

- The service file contains `${AUDITME_PROJECT_DIR}` placeholder
- During installation, `envsubst` replaces it with your actual project path
- This makes the service portable across different installations
- No hardcoded paths in version control

## Files

- **auditme.service** - Systemd service unit file
- **install-service.sh** - Installation script
- **uninstall-service.sh** - Removal script
- **README.md** - This file

## Quick Installation

```bash
# Install and enable the service
sudo ./service/install-service.sh
```

The script will:
1. Install the service to `/etc/systemd/system/`
2. Configure it to start on boot
3. Ask if you want to start it immediately

## Manual Installation

If you prefer to install manually:

```bash
# Get the project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Set environment variable
export AUDITME_PROJECT_DIR="$PROJECT_DIR"

# Copy service file with environment variable substitution
envsubst < service/auditme.service | sudo tee /etc/systemd/system/auditme.service > /dev/null

# Reload systemd
sudo systemctl daemon-reload

# Enable service
sudo systemctl enable auditme.service

# Start service
sudo systemctl start auditme.service
```

## Service Management

### Start/Stop/Restart

```bash
# Start the service
sudo systemctl start auditme

# Stop the service
sudo systemctl stop auditme

# Restart the service
sudo systemctl restart auditme

# Reload docker compose (restart containers)
sudo systemctl reload auditme
```

### Status and Logs

```bash
# Check service status
sudo systemctl status auditme

# View service logs
sudo journalctl -u auditme -f

# View last 100 lines
sudo journalctl -u auditme -n 100

# View logs since boot
sudo journalctl -u auditme -b
```

### Enable/Disable Auto-start

```bash
# Enable auto-start on boot
sudo systemctl enable auditme

# Disable auto-start on boot
sudo systemctl disable auditme

# Check if enabled
sudo systemctl is-enabled auditme
```

## Uninstallation

```bash
# Remove the service
sudo ./service/uninstall-service.sh
```

Or manually:

```bash
# Stop and disable
sudo systemctl stop auditme
sudo systemctl disable auditme

# Remove service file
sudo rm /etc/systemd/system/auditme.service

# Reload systemd
sudo systemctl daemon-reload
sudo systemctl reset-failed
```

## Service Features

### Automatic Startup
- Service starts automatically on system boot
- Starts after Docker service is ready
- Waits for network to be online

### Auto-restart on Failure
- Service restarts automatically if it fails
- 10-second delay between restart attempts
- Prevents rapid restart loops

### Container Management
- Pulls latest images on start (optional)
- Removes orphaned containers
- Graceful shutdown of all containers
- Configurable timeouts

### Security Hardening
- Private temporary directory (`PrivateTmp=yes`)
- No new privileges (`NoNewPrivileges=yes`)
- Optional resource limits (CPU, memory)

## Customization

Edit `/etc/systemd/system/auditme.service` to customize:

### Change Working Directory

The working directory is automatically set during installation using the `AUDITME_PROJECT_DIR` environment variable.

To verify the current setting:

```bash
# View current setting
grep WorkingDirectory /etc/systemd/system/auditme.service

# To change it, set the environment variable and reinstall
export AUDITME_PROJECT_DIR=/path/to/your/auditme
envsubst < service/auditme.service | sudo tee /etc/systemd/system/auditme.service > /dev/null
sudo systemctl daemon-reload
```

### Adjust Timeouts

```ini
TimeoutStartSec=180    # Increase if containers take longer to start
TimeoutStopSec=120     # Increase for graceful shutdown
```

### Set Resource Limits

Uncomment and adjust these lines:

```ini
MemoryLimit=2G         # Limit total memory usage
CPUQuota=80%           # Limit CPU usage
```

### Disable Auto-pull

Remove or comment out this line if you don't want to auto-update:

```ini
ExecStartPre=/usr/bin/docker compose -f docker-compose.yml pull --quiet --ignore-pull-failures
```

### Change User (Not Recommended)

By default, the service runs as root (required for Docker). If you want to run as a different user:

```ini
User=youruser
Group=docker
```

**Note**: The user must have Docker permissions.

## Troubleshooting

### Service fails to start

```bash
# Check detailed status
sudo systemctl status auditme -l

# View logs with errors
sudo journalctl -u auditme -p err

# Check Docker service
sudo systemctl status docker

# Verify docker compose works manually
# (Replace with your actual project path)
cd /path/to/auditme
docker compose up -d
```

### Containers don't start

```bash
# View Docker logs
docker compose logs

# Check Docker daemon
sudo systemctl status docker

# Check for port conflicts
sudo netstat -tulpn | grep -E '3000|8086|2020'
```

### Service starts but containers stop

```bash
# Check .env file exists in your project directory
ls -la .env

# Verify environment variables
docker compose config

# Check container logs
docker compose logs influxdb3
docker compose logs fluent-bit
docker compose logs grafana
```

### Service doesn't start on boot

```bash
# Verify service is enabled
sudo systemctl is-enabled auditme

# Check systemd dependencies
systemctl list-dependencies auditme

# Enable again
sudo systemctl enable auditme
```

### Permission issues

```bash
# Verify service file permissions
ls -l /etc/systemd/system/auditme.service

# Should be: -rw-r--r-- root root

# Fix permissions if needed
sudo chmod 644 /etc/systemd/system/auditme.service
```

## Best Practices

1. **Always test manually first**: Before enabling the service, make sure `docker compose up -d` works correctly.

2. **Check logs regularly**: Monitor service logs to catch issues early:
   ```bash
   sudo journalctl -u auditme -f
   ```

3. **Update carefully**: When updating the service file:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl restart auditme
   ```

4. **Backup before changes**: Keep a backup of working configuration:
   ```bash
   sudo cp /etc/systemd/system/auditme.service /etc/systemd/system/auditme.service.bak
   ```

5. **Monitor resources**: Check system resources if you enable limits:
   ```bash
   systemctl show auditme | grep -E 'Memory|CPU'
   ```

## System Requirements

- **Operating System**: Linux with systemd (Debian, Ubuntu, Fedora, etc.)
- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+
- **Root access**: Required for systemd service installation
- **Systemd**: Version 219+ recommended
- **envsubst**: Part of gettext-base package (auto-installed if missing)

## Integration with Docker

The service uses `Type=oneshot` with `RemainAfterExit=yes`, which means:
- The service starts Docker Compose and exits
- Systemd considers it "active" as long as containers are running
- Stopping the service runs `docker compose down`
- Containers are managed by Docker, not directly by systemd

This is the recommended approach for Docker Compose services.

## Related Documentation

- Main README: [../README.md](../README.md)
- Docker Compose: [../docker-compose.yml](../docker-compose.yml)
- Systemd Documentation: https://www.freedesktop.org/software/systemd/man/systemd.service.html

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. View service logs: `sudo journalctl -u auditme -f`
3. Test Docker Compose manually: `docker compose up -d`
4. Open an issue in the repository

---

**Last Updated**: November 2025
