# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository builds a custom Fedora Silverblue container image with additional packages (OpenH264 codecs, powertop). The image is published to GitHub Container Registry and can be rebased onto using rpm-ostree.

## Build Commands

**Local build (requires podman or buildah):**
```bash
podman build -t fedora-silverblue:local .
```

**CI builds** run automatically via GitHub Actions on push and daily at 15:00 UTC. Images are pushed to `ghcr.io/stefanhoelzl/fedora-silverblue:latest` on main branch pushes.

## Architecture

- `Containerfile` - Container image definition using rpm-ostree to layer packages onto Fedora Silverblue base
- `.github/workflows/build.yaml` - CI/CD pipeline using Buildah to build and push images to GHCR

## Key Concepts

- **rpm-ostree**: Package manager for immutable Fedora variants. Use `rpm-ostree override remove` to replace base packages and `rpm-ostree install` to add new packages.
- **Fedora Silverblue**: Immutable desktop OS where the base system is read-only. Customizations are applied via container image layering.
- All package operations must be combined in a single RUN statement to minimize image layers.
