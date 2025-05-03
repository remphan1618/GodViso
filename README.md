# VisoMaster Deployment Guide: GitHub Actions -> DockerHub -> Vast.ai (Jupyter)

**Current UTC Date/Time:** `2025-05-03 15:10:44`
**User:** `remphan1618`

**Welcome!** This guide provides a comprehensive walkthrough for deploying the VisoMaster application using an automated pipeline. We'll go from your source code in GitHub, build a Docker image using GitHub Actions, push it to DockerHub, and finally run it on a Vast.ai instance with GPU support, specifically using their Jupyter Notebook launch environment.

This guide covers **two main deployment options**:
1.  **Primary:** Standard deployment with direct VNC access.
2.  **Alternative (Portal):** Integrated deployment using Vast.ai's "Instance Portal" / "Open Button" feature for secure web-based access.

This guide is designed for **beginners** with coding, Docker, and cloud platforms. We'll explain the concepts and steps clearly.

**The Goal:** To have a repeatable, automated way to get the VisoMaster application running in a cloud environment with the necessary GPU hardware, accessible via Vast.ai's Jupyter interface, with options for either direct VNC or a secure web portal.

**Internal Guide:** Once your instance is running on Vast.ai (using either primary or portal setup), you'll find an interactive Jupyter Notebook named `Install_Guide.ipynb` inside the container. That notebook is your primary tool for **validating** the setup, **troubleshooting** issues, viewing **logs**, and performing **manual fixes** *after* launch. This document focuses on getting you *to* that point.

---

## Table of Contents

1.  [Pipeline Overview](#1-pipeline-overview)
2.  [Core Concepts Explained](#2-core-concepts-explained)
    *   [Docker (Images vs. Containers)](#docker-images-vs-containers)
    *   [Miniconda & Virtual Environments](#miniconda--virtual-environments)
    *   [CUDA (Runtime vs. Drivers)](#cuda-runtime-vs-drivers)
    *   [Vast.ai Basics (Instances, Jupyter, Storage, GPU, Portal)](#vastai-basics)
    *   [GitHub Actions (CI/CD)](#github-actions-cicd)
    *   [DockerHub (Registry)](#dockerhub-registry)
    *   [Supervisor (Process Management)](#supervisor-process-management)
    *   [VNC/GUI in Docker](#vncgui-in-docker)
    *   [Caddy (Web Server - for Portal)](#caddy-web-server---for-portal)
3.  [Prerequisites](#3-prerequisites)
4.  [Repository Structure](#4-repository-structure)
5.  [Setup Steps (Common)](#5-setup-steps-common)
    *   [Populating the `dependencies` Folder](#populating-the-dependencies-folder)
    *   [Review `requirements.txt`](#review-requirementstxt)
    *   [GitHub Secrets Configuration](#github-secrets-configuration)
6.  **Option 1: Primary Deployment (Direct VNC)**
    *   [Build Process (GitHub Actions - Primary)](#build-process-github-actions---primary)
    *   [Launching on Vast.ai (Primary)](#launching-on-vastai-primary)
    *   [Accessing (Primary - VNC & Jupyter)](#accessing-primary---vnc--jupyter)
7.  **Option 2: Alternative Deployment (Instance Portal)**
    *   [Understanding the `alt/` Folder](#understanding-the-alt-folder)
    *   [Build Process (GitHub Actions - Portal)](#build-process-github-actions---portal)
    *   [Launching on Vast.ai (Portal)](#launching-on-vastai-portal)
    *   [Accessing (Portal - Open Button & Jupyter)](#accessing-portal---open-button--jupyter)
8.  [Using the Internal `Install_Guide.ipynb`](#8-using-the-internal-install_guideipynb)
9.  [Understanding the Configuration Files](#9-understanding-the-configuration-files)
    *   [Primary Files (`Dockerfile`, `supervisord.conf`, `docker-compose.yml`, `.github/workflows/build-primary.yml`)](#primary-files)
    *   [Alternative Portal Files (`alt/Dockerfile`, `alt/Caddyfile`, `alt/supervisord.conf`, `alt/docker-compose.yml`, `.github/workflows/build-alt-portal.yml`)](#alternative-portal-files)
    *   [Shared Files (`Install_Guide.ipynb`, `requirements.txt`, `dependencies/`)](#shared-files)
10. [Other Alternatives (Provisioning Script)](#10-other-alternatives-provisioning-script)
11. [Logging & Troubleshooting](#11-logging--troubleshooting)
    *   [GitHub Actions Logs](#github-actions-logs)
    *   [DockerHub](#dockerhub)
    *   [Vast.ai Instance Logs (UI Button)](#vastai-instance-logs-ui-button)
    *   [Inside the Container (via `Install_Guide.ipynb`)](#inside-the-container-via-install_guideipynb)
12. [Conclusion](#12-conclusion)

---

## 1. Pipeline Overview

This diagram shows how the pieces fit together (applies to both Primary and Portal options, differing mainly in build/runtime config):

```mermaid
graph LR
    A[1. Your Code (GitHub Repo)\n- VisoMaster Code\n- dependencies/\n- requirements.txt\n- Config Files (Primary OR Alt)\n- Workflows\n- Install_Guide.ipynb] --> B{2. GitHub Actions (Build)};
    B -- Build Image --> C[3. DockerHub (Registry)\n- Stores your_username/visomaster:latest\n- OR your_username/visomaster:portal-latest];
    C -- Pull Image --> D{4. Vast.ai Instance (Jupyter Launch)\n- Runs Container\n- Provides GPU\n- Uses /workspace\n- Access via Jupyter UI\n- Access via VNC (Primary) OR Portal (Alt)};
    D -- Access --> E[5. User Interaction\n- Connect via VNC/Portal\n- Use Jupyter Interface\n- Run Install_Guide.ipynb];

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#ccf,stroke:#333,stroke-width:2px
    style C fill:#9cf,stroke:#333,stroke-width:2px
    style D fill:#cff,stroke:#333,stroke-width:2px
    style E fill:#cfc,stroke:#333,stroke-width:2px
```

*   **Source (GitHub):** You store your application code (`VisoMaster`), required assets (`dependencies/`), Python packages (`requirements.txt`), the internal guide (`Install_Guide.ipynb`), and the configuration files. You choose *either* the primary set (`Dockerfile`, `supervisord.conf`, `build-primary.yml`) *or* the alternative portal set (`alt/Dockerfile`, `alt/supervisord.conf`, `alt/Caddyfile`, `build-alt-portal.yml`).
*   **Build (GitHub Actions):** Based on which workflow runs (`build-primary.yml` or `build-alt-portal.yml`), the corresponding Dockerfile (`Dockerfile` or `alt/Dockerfile`) is used to build the image.
*   **Artifact (DockerHub):** The image is pushed with a relevant tag (`latest` for primary, `portal-latest` for the alternative).
*   **Deployment & Runtime (Vast.ai):** You launch a Vast.ai instance using the Jupyter template, specifying the correct Docker image tag (`latest` or `portal-latest`) and configuring ports/environment variables according to the chosen option (direct VNC port map or Caddy portal port map + `PORTAL_CONFIG`).
*   **Interaction:** You access the running application via direct VNC (Primary) or the secure web portal (Alternative). You can *always* access the container's environment, including the `Install_Guide.ipynb`, via the Vast.ai Jupyter interface.

---

## 2. Core Concepts Explained

*   **Docker (Images vs. Containers):** Blueprint vs. running instance. Packages app + dependencies. Ensures consistency.
*   **Miniconda & Virtual Environments:** Manages isolated Python environments (`visomaster`) and complex dependencies (like CUDA via Conda).
*   **CUDA (Runtime vs. Drivers):** Runtime/Toolkit (installed in Docker via Conda) needed by the app; Drivers (on Vast.ai host) talk to hardware.
*   **Vast.ai Basics:**
    *   **Instances:** Rentable VMs/containers with GPUs.
    *   **Jupyter Launch Mode:** Provides web-based JupyterLab access (terminal, files, notebooks).
    *   **`/workspace` Storage:** Persistent storage inside the container.
    *   **GPU:** Hardware acceleration provided by Vast.ai.
    *   **Instance Portal / Open Button:** Optional secure web dashboard (uses Caddy) for accessing services (VNC, logs) via a token. See Alternative setup. (Context: [Vast.ai Base Images](https://github.com/vast-ai/base-image))
*   **GitHub Actions (CI/CD):** Automates build/push process via workflows (`.yml` files).
*   **DockerHub (Registry):** Stores and distributes Docker images.
*   **Supervisor (Process Management):** Runs multiple services (VNC, app, Caddy) inside the container. Configured via `supervisord.conf`.
*   **VNC/GUI in Docker:** Uses Xvfb (virtual display), Fluxbox (window manager), x11vnc (server) for remote GUI access.
*   **Caddy (Web Server - for Portal):** Used in the alternative setup to provide secure HTTPS proxying for VNC and log access via the web portal. Configured via `alt/Caddyfile`. (Docs: [Caddy](https://caddyserver.com/docs/))

---

## 3. Prerequisites

(Same as before: Git, GitHub account, Docker Desktop (optional), DockerHub account, Vast.ai account, VisoMaster code, VisoMaster assets)

---

## 4. Repository Structure

Organize your repository as follows:

```
your-repo-name/
├── VisoMaster/             # VisoMaster application code
├── dependencies/           # User-provided assets
├── alt/                    # Folder for Portal Alternative Set
│   ├── Dockerfile          # Portal Dockerfile
│   ├── Caddyfile           # Portal Caddy config
│   ├── supervisord.conf    # Portal supervisord config
│   └── docker-compose.yml  # Portal compose (reference)
├── .github/
│   └── workflows/
│       ├── build-primary.yml   # Primary workflow
│       └── build-alt-portal.yml # Portal workflow
├── Dockerfile              # Primary Dockerfile
├── supervisord.conf        # Primary supervisord config
├── docker-compose.yml      # Primary compose (reference)
├── requirements.txt        # Python dependencies
├── Install_Guide.ipynb     # Internal guide (used by both)
├── README.md               # This file
└── provisioning_script.sh  # Example provisioning script (if used)
```

---

## 5. Setup Steps (Common)

These steps apply regardless of whether you choose the Primary or Portal deployment.

1.  **Clone Your Repo:** Clone your GitHub repository locally.
2.  **Add VisoMaster Code:** Copy the VisoMaster application code into the `VisoMaster/` directory.
3.  **Add Config Files:** Copy all the configuration files (`Dockerfile`, `supervisord.conf`, `docker-compose.yml`, `Install_Guide.ipynb`, `README.md`, `requirements.txt`, `provisioning_script.sh`, the `.github/workflows` files, and the entire `alt/` directory) into your repository, matching the structure above.
4.  **Populate `dependencies/` Folder:**
    *   **CRUCIAL:** Download necessary assets (models, data files *excluding* source code zip) from VisoMaster asset releases (e.g., `https://github.com/visomaster/visomaster-assets/releases/tag/v0.1.0_dp`).
    *   Place these downloaded files directly inside the `dependencies/` folder. Both `Dockerfile` and `alt/Dockerfile` copy from this location.
5.  **Review `requirements.txt`:** Ensure it's the correct file from VisoMaster, as it's used by both Dockerfiles with specific index URLs.
6.  **GitHub Secrets Configuration:**
    *   Go to your GitHub repo > Settings > Secrets and variables > Actions.
    *   Create `DOCKERHUB_USERNAME` (your DockerHub username).
    *   Create `DOCKERHUB_TOKEN` (a DockerHub Access Token with Read/Write permissions).
7.  **Commit and Push:**
    ```bash
    git add .
    git commit -m "Setup VisoMaster deployment files (primary and alt)"
    git push origin main
    ```

---

## 6. Option 1: Primary Deployment (Direct VNC)

This is the standard setup providing direct VNC access.

*   ### Build Process (GitHub Actions - Primary)
    *   Pushing to the `main` branch triggers the `.github/workflows/build-primary.yml` workflow.
    *   This uses the root `Dockerfile` to build the image.
    *   It pushes the image to DockerHub as `your_dockerhub_username/visomaster:latest` and `your_dockerhub_username/visomaster:<commit-sha>`.
    *   Monitor progress in the "Actions" tab on GitHub.

*   ### Launching on Vast.ai (Primary)
    1.  **Go to Vast.ai Create/Templates.**
    2.  **Choose Template:** Select "Jupyter Notebook + Persistent /workspace".
    3.  **Docker Image:** Enter `your_dockerhub_username/visomaster:latest`.
    4.  **GPU:** Select a suitable GPU.
    5.  **Storage:** Allocate disk space.
    6.  **Port Mapping:** Map Host Port `5901` (or another available port) to Container Port `5901`. Note the assigned Host Port.
    7.  **Environment Variables:** Add any needed by VisoMaster.
    8.  **Review and Launch.** Wait for the instance status to become "Running".

*   ### Accessing (Primary - VNC & Jupyter)
    1.  **VNC:** Use a VNC client to connect to `<Instance_IP_Address>:<VNC_Host_Port>` (the host port you noted from the mapping).
    2.  **Jupyter:** Click the "Jupyter" or "Open" button on the Vast.ai instance page to access the JupyterLab interface (files, terminal, notebooks).

---

## 7. Option 2: Alternative Deployment (Instance Portal)

This setup uses Vast.ai's integrated web portal for secure access.

*   ### Understanding the `alt/` Folder
    *   This folder contains a *complete set* of configuration files designed to work together for the portal setup.
    *   `alt/Dockerfile`: Installs Caddy webserver.
    *   `alt/Caddyfile`: Configures Caddy for secure proxying.
    *   `alt/supervisord.conf`: Runs Caddy, VNC (localhost only), and the app, logging to `/var/log/portal`.

*   ### Build Process (GitHub Actions - Portal)
    *   This build is **triggered manually**.
    *   Go to the "Actions" tab on GitHub.
    *   Select the "Build and Push VisoMaster ALT-PORTAL Docker Image" workflow from the list on the left.
    *   Click the "Run workflow" button (usually requires selecting the branch, typically `main`).
    *   This workflow (`.github/workflows/build-alt-portal.yml`) uses `alt/Dockerfile` to build the portal-enabled image.
    *   It pushes the image to DockerHub as `your_dockerhub_username/visomaster:portal-latest` and `your_dockerhub_username/visomaster:portal-<commit-sha>`.

*   ### Launching on Vast.ai (Portal)
    1.  **Go to Vast.ai Create/Templates.**
    2.  **Choose Template:** Select "Jupyter Notebook + Persistent /workspace".
    3.  **Docker Image:** Enter `your_dockerhub_username/visomaster:portal-latest` (use the specific portal tag).
    4.  **GPU:** Select a suitable GPU.
    5.  **Storage:** Allocate disk space.
    6.  **Port Mapping:** Map a Host Port (e.g., 1111, Vast.ai will assign one) to Container Port **`11111`** (the internal Caddy port). **DO NOT map port 5901 directly.**
    7.  **Environment Variables:**
        *   **CRITICAL:** Add a variable named `PORTAL_CONFIG`.
        *   Paste the following JSON string as its value (ensure it's exactly copied):
            ```json
            {"version":2,"port":11111,"services":[{"name":"VNC","uri":"/vnc/","proto":"http","rewrite":true,"auth":true},{"name":"AppLogs","uri":"/logs/visomaster_app.log","auth":true},{"name":"VNCLogs","uri":"/logs/x11vnc.log","auth":true},{"name":"CaddyLogs","uri":"/logs/caddy.log","auth":true},{"name":"LogBrowse","uri":"/logs/","auth":true}]}
            ```
        *   Add any other variables needed by VisoMaster.
    8.  **Review and Launch.** Wait for the instance status to become "Running".

*   ### Accessing (Portal - Open Button & Jupyter)
    1.  **Portal ("Open" Button):** Click the main "Open" button on the Vast.ai instance page. This securely connects you to the Caddy web portal running inside the container. Use the links ("VNC", "AppLogs", etc.) provided within the portal interface.
    2.  **Jupyter:** Click the separate "Jupyter" button/link on the Vast.ai instance page to access the standard JupyterLab interface (files, terminal, notebooks).

---

## 8. Using the Internal `Install_Guide.ipynb`

*   **Access:** Open the Jupyter interface (via the "Jupyter" button on Vast.ai, works for both Primary and Portal setups). Navigate to `/app/VisoMaster/` and open `Install_Guide.ipynb`.
*   **Purpose:** Your essential **in-container** tool for:
    *   **Validation:** Run checks (Shift+Enter) to verify setup (Conda, CUDA, Python, packages, GPU, services).
    *   **Troubleshooting:** View logs, restart services (`supervisorctl restart ...`).
    *   **Manual Fixes:** Copy/paste commands into a Jupyter terminal if automated build steps failed.
*   **Log Locations:** The notebook helps view logs. Note that for the Portal setup, application and VNC logs are in `/var/log/portal/`, while for the Primary setup, they are in `/var/log/supervisor/`. The notebook should guide you.

---

## 9. Understanding the Configuration Files

*   ### Primary Files
    *   `Dockerfile`: Builds standard image (Conda, CUDA, GUI tools, app, VNC port 5901).
    *   `supervisord.conf`: Runs VNC (public), app. Logs to `/var/log/supervisor/`.
    *   `docker-compose.yml`: Reference for VNC port map, GPU, volume.
    *   `.github/workflows/build-primary.yml`: Builds primary image on push to `main`, tags `latest`.

*   ### Alternative Portal Files (`alt/`)
    *   `alt/Dockerfile`: Builds portal image (adds Caddy install).
    *   `alt/Caddyfile`: Configures Caddy (listens 11111, auth, proxies VNC/logs).
    *   `alt/supervisord.conf`: Runs Caddy, VNC (localhost), app. Logs to `/var/log/portal/`.
    *   `alt/docker-compose.yml`: Reference for Caddy port map (`Host:11111`), `PORTAL_CONFIG` variable.
    *   `.github/workflows/build-alt-portal.yml`: Builds portal image manually (`workflow_dispatch`), tags `portal-latest`.

*   ### Shared Files
    *   `Install_Guide.ipynb`: Internal validation/troubleshooting notebook (used by both setups).
    *   `requirements.txt`: Python dependencies (used by both Dockerfiles).
    *   `dependencies/`: Folder for assets (used by both Dockerfiles).
    *   `VisoMaster/`: Application code.

---

## 10. Other Alternatives (Provisioning Script)

*   **Strategy:** Use Vast.ai's `PROVISIONING_SCRIPT` environment variable to run a script (like `provisioning_script.sh`) *after* container start but *before* `supervisord`.
*   **Use Case:** Download large models at instance startup instead of during Docker build.
*   **Pros:** Smaller image, faster builds/pushes.
*   **Cons:** Slower instance startup, requires instance internet, potential runtime download failures.
*   **Implementation:** Remove model download `RUN` command from `Dockerfile` (or `alt/Dockerfile`). Set `PROVISIONING_SCRIPT` in Vast.ai launch config (either URL to script or embed script content).

---

## 11. Logging & Troubleshooting

*   **GitHub Actions Logs:** Check build failures in the "Actions" tab on GitHub.
*   **DockerHub:** Verify image tags (`latest` or `portal-latest`) exist after successful builds.
*   **Vast.ai Instance Logs (UI Button):** Check initial startup errors (image pull, Docker errors, provisioning script output).
*   **Inside the Container (via `Install_Guide.ipynb`):** **PRIMARY tool** post-launch. Use the notebook in the Jupyter interface to check service status (`supervisorctl status`) and view detailed logs (`/var/log/supervisor/*` for primary, `/var/log/portal/*` for portal).

---

## 12. Conclusion

This repository provides two deployment options for VisoMaster on Vast.ai: a standard direct VNC setup (Primary) and a secure web portal setup (Alternative). Follow the steps for your chosen option, ensuring you build the correct image and configure Vast.ai accordingly. Use the `Install_Guide.ipynb` within the running instance for validation and troubleshooting. Good luck!