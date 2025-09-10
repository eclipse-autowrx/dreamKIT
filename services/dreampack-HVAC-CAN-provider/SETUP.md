# Setup Instructions

Before using the dk_service_can_provider, you need to customize it with your information.

## 🔧 Required Customizations

### 1. Update GitHub Container Registry URLs

Replace `YOUR_USERNAME` with your actual GitHub username in these files:

#### **build.sh**
```bash
# Find and replace in build_prod() function:
-t ghcr.io/YOUR_USERNAME/${IMAGE_NAME}:${VERSION} \
-t ghcr.io/YOUR_USERNAME/${IMAGE_NAME}:latest \
```

#### **manifests/mirror-remote.yaml**
```yaml
# Update the source URL:
- "docker://ghcr.io/YOUR_USERNAME/dk_service_can_provider:latest"
```

#### **marketplace_template.json**
```json
{
  "vendor": "YOUR_USERNAME",
  "DockerImageURL": "ghcr.io/YOUR_USERNAME/dk_service_can_provider:latest",
  "Documentation": {
    "readme": "https://github.com/YOUR_USERNAME/dk_service_can_provider/blob/main/README.md",
    "deployment": "https://github.com/YOUR_USERNAME/dk_service_can_provider/blob/main/DEPLOYMENT.md"
  }
}
```

### 2. Setup GitHub Container Registry Access

#### **Configure Docker for GHCR**
```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Or use personal access token
docker login ghcr.io -u YOUR_USERNAME
```

#### **Required GitHub Permissions**
Your GitHub Personal Access Token needs these scopes:
- `write:packages` - Push container images
- `read:packages` - Pull container images
- `delete:packages` - Delete container images (optional)

### 3. Verify Setup

#### **Test Build and Push**
```bash
# Build and push to verify GHCR access
./build.sh prod v0.1.0 --push

# Verify image is accessible
docker pull ghcr.io/YOUR_USERNAME/dk_service_can_provider:v0.1.0
```

#### **Test Mirror Jobs**
```bash
# Test local mirror (after building locally)
./build.sh prod
kubectl apply -f manifests/mirror-local.yaml
kubectl logs job/mirror-dk-service-can-provider-local

# Test remote mirror (after pushing to GHCR)
kubectl apply -f manifests/mirror-remote.yaml  
kubectl logs job/mirror-dk-service-can-provider-remote
```

## 🗂️ File Checklist

After customization, verify these files contain your information:

- [ ] `build.sh` - GHCR URLs updated
- [ ] `manifests/mirror-remote.yaml` - GHCR URL updated
- [ ] `marketplace_template.json` - All URLs and vendor updated
- [ ] GitHub Personal Access Token configured
- [ ] Docker logged into GHCR

## 🚀 Quick Setup Script

Create a `setup.sh` script to automate the customization:

```bash
#!/bin/bash

# Replace YOUR_USERNAME with your GitHub username
USERNAME="your-github-username"

# Update build.sh
sed -i "s/YOUR_USERNAME/$USERNAME/g" build.sh

# Update mirror-remote.yaml  
sed -i "s/YOUR_USERNAME/$USERNAME/g" manifests/mirror-remote.yaml

# Update marketplace template
sed -i "s/YOUR_USERNAME/$USERNAME/g" marketplace_template.json

echo "✅ Setup complete! Your username: $USERNAME"
echo "🔑 Don't forget to configure GHCR access:"
echo "   docker login ghcr.io -u $USERNAME"
```

## 🔍 Troubleshooting Setup

### **GHCR Access Issues**
```bash
# Check if you're logged in
docker info | grep -i registry

# Test push access
docker tag dk_service_can_provider:latest ghcr.io/YOUR_USERNAME/test:latest
docker push ghcr.io/YOUR_USERNAME/test:latest
```

### **Mirror Job Failures**
```bash
# Check mirror job logs
kubectl logs job/mirror-dk-service-can-provider-local
kubectl logs job/mirror-dk-service-can-provider-remote

# Common issues:
# 1. GHCR URL not updated → Update manifests/mirror-remote.yaml
# 2. Access denied → Check GHCR login and permissions
# 3. Image not found → Verify image exists with: docker images
```

### **Build Script Issues**
```bash
# Check if YOUR_USERNAME was replaced
grep -r "YOUR_USERNAME" .

# If found, update manually or run setup script again
```

Once setup is complete, proceed with the development workflows in README.md.