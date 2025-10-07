# Docker Image Publishing

This repository automatically builds and publishes Docker images to DockerHub and Quay.io on pushes to the main branch and on version tags.

## Container Registries

- **DockerHub**: `docker.io/clpi/wx`
- **Quay.io**: `quay.io/clpi/wx`

## Required Secrets

To enable automatic publishing, the following GitHub secrets must be configured in the repository settings:

### DockerHub Secrets

1. `DOCKERHUB_USERNAME` - Your DockerHub username
2. `DOCKERHUB_TOKEN` - DockerHub access token (create at https://hub.docker.com/settings/security)

### Quay.io Secrets

1. `QUAY_USERNAME` - Your Quay.io username/robot account name
2. `QUAY_TOKEN` - Quay.io access token or robot account token

## Setting up Secrets

### Via GitHub Web UI

1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each of the four secrets listed above

### Creating Access Tokens

#### DockerHub Token

1. Go to https://hub.docker.com/settings/security
2. Click "New Access Token"
3. Give it a name (e.g., "GitHub Actions")
4. Select appropriate permissions (Read, Write, Delete)
5. Copy the token and add it as `DOCKERHUB_TOKEN` secret

#### Quay.io Token

1. Go to https://quay.io/organization/USERNAME?tab=robots (replace USERNAME)
2. Create a new robot account or use an existing one
3. Grant write permissions to the repository
4. Copy the robot account credentials or generate a new token
5. Add the username as `QUAY_USERNAME` and token as `QUAY_TOKEN`

## Image Tags

The workflow automatically creates the following tags:

- `latest` - Latest build from the main branch
- `<branch>` - Branch name for branch builds
- `v<version>` - Semantic version tags (e.g., v0.1.0)
- `<major>.<minor>` - Major.minor version tags (e.g., 0.1)
- `<major>` - Major version tags (e.g., 0)
- `<branch>-<sha>` - Branch name with commit SHA

## Multi-Architecture Support

Images are built for the following platforms:

- `linux/amd64` (x86_64)
- `linux/arm64` (aarch64)

## Using the Images

```bash
# Pull the latest image
docker pull clpi/wx:latest

# Run a WebAssembly file
docker run -v $(pwd):/workspace clpi/wx:latest your-file.wasm

# Run with specific tag
docker pull clpi/wx:v0.1.0
docker run -v $(pwd):/workspace clpi/wx:v0.1.0 your-file.wasm
```

## Building Locally

To build the Docker image locally:

```bash
# Build for your current platform
docker build -t wx:local .

# Build for multiple platforms (requires buildx)
docker buildx build --platform linux/amd64,linux/arm64 -t wx:local .
```

## Workflow Triggers

The Docker workflow runs on:

- Pushes to `main` branch
- Pull requests (builds but doesn't push)
- Git tags starting with `v` (e.g., v1.0.0)
- Manual workflow dispatch

## Troubleshooting

### Images not publishing

1. Verify all four secrets are set correctly in repository settings
2. Check the GitHub Actions workflow logs for authentication errors
3. Ensure the DockerHub/Quay.io repositories exist and you have write access

### Build failures

1. Check that the Dockerfile syntax is correct
2. Verify Zig version compatibility
3. Review build logs in GitHub Actions

### Multi-arch build issues

If multi-architecture builds fail, you may need to:
1. Use a different base image that supports both platforms
2. Check if all dependencies are available for both architectures
