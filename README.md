# GitHub Actions Self-Hosted Runners

A Docker Compose setup for running ephemeral GitHub Actions self-hosted runners. This repository provides a containerized solution for running GitHub Actions workflows on your own infrastructure with automatic scaling, self-cleaning ephemeral runners, and a janitor service for maintenance.

## Purpose

This setup allows you to:
- Run GitHub Actions workflows on your own infrastructure
- Use ephemeral runners that automatically deregister after each job
- Scale runners up and down based on demand
- Support repository, organization, or enterprise-level runner registration
- Automatically clean up old runner data and maintain target runner count
- Eliminate ghost runners through ephemeral design

## Quick Start

### 1. Clone and Setup

```bash
git clone <this-repo>
cd github-runners
```

### 2. Create Environment File

Create a `.env` file with your configuration:

```bash
# Required: GitHub Personal Access Token
ACCESS_TOKEN=ghp_your_token_here

# Required: Choose ONE of the following
ORG=your-org-name          # For organization-level runners
# OR
REPO=owner/repo-name       # For repository-level runners  
# OR
ENTERPRISE=your-enterprise # For enterprise-level runners

# Optional: Customize runner settings
LABELS=self-hosted,linux,x64,ephemeral
RUNNER_NAME=my-runner-1
```

### 3. Set Up the Janitor

```bash
# Set up cron job to run janitor every 5 minutes
*/5 * * * * /path/to/github-runners/janitor.sh

# Or run janitor manually to start runners
./janitor.sh
```

### 4. Verify Registration

Check your GitHub repository/organization settings to see the registered runners, or run the test workflow:

```bash
# Trigger the test workflow via GitHub CLI
gh workflow run "self-hosted test"
```

## Configuration Options

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ACCESS_TOKEN` | ✅ | - | GitHub Personal Access Token with appropriate permissions |
| `ORG` | * | - | Organization name for org-level runners |
| `REPO` | * | - | Repository name (owner/repo) for repo-level runners |
| `ENTERPRISE` | * | - | Enterprise name for enterprise-level runners |
| `LABELS` | ❌ | `self-hosted,ephemeral` | Comma-separated labels for the runner |
| `RUNNER_NAME` | ❌ | `$(hostname)` | Unique name for this runner instance |

*One of `ORG`, `REPO`, or `ENTERPRISE` must be set.

### Required GitHub Token Permissions

Your `ACCESS_TOKEN` needs the following permissions:
- **For Repository runners**: `repo` (full control)
- **For Organization runners**: `admin:org` (write access)
- **For Enterprise runners**: `admin:enterprise` (write access)

## Ephemeral Runners

### How Ephemeral Runners Work

This setup uses **ephemeral runners** that:
- Register with GitHub when the container starts
- Run a single job and then automatically deregister
- Terminate the container after job completion
- Eliminate ghost runners by design

### Scaling with Janitor Service

The janitor service automatically:
- Maintains your target number of runners
- Cleans up old runner data and containers
- Scales up when runners are missing
- Can be run manually or via cron job

```bash
# Run janitor manually
./janitor.sh

# Or run via cron (every 5 minutes)
*/5 * * * * /path/to/github-runners/janitor.sh
```

### Scaling with Janitor Script

The janitor script handles runner scaling and cleanup automatically:

```bash
# Run janitor manually
./janitor.sh

# Set up cron job (every 5 minutes)
*/5 * * * * /path/to/github-runners/janitor.sh
```

The janitor script:
- Maintains your target number of runners
- Cleans up old runner data and containers
- Scales up when runners are missing
- Eliminates the need for manual scaling

## Important Caveats & Gotchas

### ✅ No More Ghost Runners!

**Ephemeral Design**: Ghost runners are eliminated by design with ephemeral runners. Each runner:
- Automatically deregisters after completing a job
- Terminates the container immediately after deregistration
- Never leaves offline runners in GitHub

**If you still see ghost runners**:
1. Check GitHub Settings → Actions → Runners
2. Remove any offline runners manually
3. Or use GitHub CLI:
   ```bash
   gh api repos/:owner/:repo/actions/runners --jq '.runners[] | select(.status=="offline") | .id' | xargs -I {} gh api -X DELETE repos/:owner/:repo/actions/runners/{}
   ```

### 🔒 Security Considerations

- **Token Security**: Never commit `.env` files to version control
- **Network Access**: Runners need outbound HTTPS access to GitHub
- **Resource Limits**: Set appropriate CPU/memory limits to prevent resource exhaustion
- **Isolation**: Consider using Docker networks for additional isolation

### 📁 Ephemeral Data

- Runner configurations are temporary and cleaned up after each job
- Work directories are ephemeral and automatically cleaned up
- No persistent runner data - each job starts fresh
- Janitor service cleans up old containers and data

### 🔄 Container Lifecycle

- Runners register when container starts
- Run a single job and deregister automatically
- Container terminates after job completion
- Janitor maintains target runner count

## Monitoring & Troubleshooting

### Check Runner Status

```bash
# Run janitor to check/scale runners
./janitor.sh

# View logs
docker compose logs -f runner

# Check running containers
docker compose ps
```

### Common Issues

1. **Registration Fails**: Check `ACCESS_TOKEN` permissions and network connectivity
2. **Jobs Not Picked Up**: Verify runner labels match workflow requirements (should include `ephemeral`)
3. **Runners Not Scaling**: Check janitor service is running and has proper permissions
4. **Memory Issues**: Adjust resource limits or scale down
5. **Old Containers Accumulating**: Run janitor service to clean up

### Logs

```bash
# Follow all logs
docker compose logs -f

# Follow specific service
docker compose logs -f runner

# View last 100 lines
docker compose logs --tail=100 runner
```

## Advanced Usage

### Custom Runner Images

Extend the base image for additional tools:

```dockerfile
FROM ghcr.io/actions/actions-runner:latest

# Install additional tools
RUN apt-get update && apt-get install -y \
    nodejs \
    python3 \
    docker.io

# Copy custom scripts
COPY scripts/ /usr/local/bin/
```

### Multiple Environments

Use different compose files for different environments:

```bash
# Development
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Production  
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
