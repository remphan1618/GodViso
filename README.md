# VisoMaster Deployment Guide: GitHub Actions -> DockerHub -> Vast.ai (Jupyter)

**Current UTC Date/Time:** `2025-05-03 19:55:41`
**User:** `remphan1618`

**Welcome!** This guide provides a comprehensive walkthrough for deploying the VisoMaster application using an automated pipeline. We'll go from your source code in GitHub, build a Docker image using **GitHub Actions runners**, push it to DockerHub, and finally run it on a Vast.ai instance with GPU support, specifically using their Jupyter Notebook launch environment.

This repository now offers **four distinct deployment configurations**, each in its own folder:

1.  **`default/`:** Standard VNC access; Models included **during build**; Copies assets from local `dependencies/` folder. (Image Tag: `latest`)
2.  **`alt/`:** Instance Portal access; Models included **during build**; Copies assets from local `dependencies/` folder. (Image Tag: `portal-latest`)
3.  **`s-def/`:** **Instance Portal access**; Models, `ffmpeg.exe`, `ffplay.exe` downloaded **at runtime**. (Image Tag: `small-latest`) - *Note: Now uses Portal access.*
4.  **`s-alt/`:** Instance Portal access; Models, `ffmpeg.exe`, `ffplay.exe` downloaded **at runtime**. (Image Tag: `small-portal-latest`)

This guide is designed for **beginners** with coding, Docker, and cloud platforms.

**The Goal:** To have multiple, repeatable, automated ways to get VisoMaster running in the cloud with GPUs, offering choices between VNC/Portal access and build-time/runtime model/asset handling (to avoid Git LFS).

**Internal Guide:** Regardless of the build option chosen, once your instance is running on Vast.ai, you'll find an interactive Jupyter Notebook named `Install_Guide.ipynb` inside the container (`/app/VisoMaster/`). Use this notebook for **validating** the setup, **troubleshooting**, viewing **logs**, and performing **manual fixes**.

---

## Table of Contents

1.  [Pipeline Overview](#1-pipeline-overview)
2.  [Core Concepts Explained](#2-core-concepts-explained)
    *   [Common Concepts](#common-concepts)
    *   [VNC / Window Manager Setup](#vnc--window-manager-setup)
    *   [Caddy (Web Server - for Portal)](#caddy-web-server---for-portal)
    *   [Runtime Download (Entrypoint Script)](#runtime-download-entrypoint-script)
3.  [Prerequisites](#3-prerequisites)
4.  [Repository Structure](#4-repository-structure)
5.  [Setup Steps (Common)](#5-setup-steps-common)
6.  **Build & Deployment Options (Choose One)**
    *   [Option 1: Default (`default/`) - VNC, Build-time Models/Assets](#option-1-default-default---vnc-build-time-modelsassets)
    *   [Option 2: Alt (`alt/`) - Portal, Build-time Models/Assets](#option-2-alt-alt---portal-build-time-modelsassets)
    *   [Option 3: Small Default (`s-def/`) - Portal, Runtime Models/Assets](#option-3-small-default-s-def---portal-runtime-modelsassets) <!-- CHANGED -->
    *   [Option 4: Small Alt (`s-alt/`) - Portal, Runtime Models/Assets](#option-4-small-alt-s-alt---portal-runtime-modelsassets)
7.  [Using the Internal `Install_Guide.ipynb`](#7-using-the-internal-install_guideipynb)
8.  [Understanding the Configuration Files](#8-understanding-the-configuration-files)
9.  [Logging & Troubleshooting](#9-logging--troubleshooting)
10. [Conclusion](#10-conclusion)

---

## 1. Pipeline Overview

<!-- Mermaid diagram remains the same -->
```mermaid
graph LR
    A[1. Your Code (GitHub Repo)\n- VisoMaster Code\n- dependencies/ (Optional, for default/alt)\n- requirements.txt\n- Install_Guide.ipynb\n- Config Folders (default/, alt/, s-def/, s-alt/)\n- Workflows] --> B{2. GitHub Actions Runner (Build)};
    B -- Build Image (Select Workflow) --> C[3. DockerHub (Registry)\n- Stores your_username/visomaster:<tag>];
    C -- Pull Image --> D{4. Vast.ai Instance (Jupyter Launch)\n- Runs Container\n- Provides GPU\n- Uses /workspace\n- Access via Jupyter UI\n- Access via VNC or Portal};
    D -- Access --> E[5. User Interaction\n- Connect via VNC/Portal\n- Use Jupyter Interface\n- Run Install_Guide.ipynb];

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#ccf,stroke:#333,stroke-width:2px
    style C fill:#9cf,stroke:#333,stroke-width:2px
    style D fill:#cff,stroke:#333,stroke-width:2px
    style E fill:#cfc,stroke:#333,stroke-width:2px
```

*   **Source (GitHub):** Contains application code, shared files, and four distinct configuration sets in the `default/`, `alt/`, `s-def/`, and `s-alt/` folders. Each set has its own Dockerfile and supporting configs. Four workflows exist in `.github/workflows/` to build each configuration. The local `dependencies/` folder is needed only if building the `default` or `alt` configurations.
*   **Build (GitHub Actions Runner):** You trigger one of the four workflows (either automatically via push for `default`, or manually for the others). A GitHub runner builds the Docker image using the `Dockerfile` from the corresponding configuration folder.
*   **Artifact (DockerHub):** The image is pushed with a tag specific to the configuration (e.g., `latest`, `portal-latest`, `small-latest`, `small-portal-latest`).
*   **Deployment & Runtime (Vast.ai):** You launch a Vast.ai instance using the Jupyter template, selecting the desired image tag and configuring ports/environment variables according to the chosen configuration (VNC port map or Portal port map + `PORTAL_CONFIG`).
*   **Interaction:** Access via VNC/Portal and the standard Jupyter interface.

---

## 2. Core Concepts Explained

<!-- Sections remain the same -->
*   ### Common Concepts
    *   **Docker (Images vs. Containers):** Blueprint vs. running instance.
    *   **Miniconda & Virtual Environments:** Isolated `visomaster` environment.
    *   **CUDA (Runtime vs. Drivers):** Runtime/Toolkit in Docker; Drivers on Vast.ai host.
    *   **Vast.ai Basics:** Instances, Jupyter Launch, `/workspace` storage, GPU access.
    *   **GitHub Actions (CI/CD & Runners):** Automation via workflows executed on GitHub-hosted VMs.
    *   **DockerHub (Registry):** Stores Docker images.
    *   **Supervisor (Process Management):** Manages services (VNC, app, Caddy) via `.conf` files.

*   ### VNC / Window Manager Setup
    *   **Purpose:** To provide a graphical desktop environment accessible remotely via VNC, suitable for running GUI applications within the container.
    *   **Components Used:**
        *   `Xvfb`: Creates a virtual, in-memory X display server (no physical screen needed).
        *   `x11vnc`: A VNC server that efficiently shares the existing X session created by Xvfb.
        *   `Fluxbox`: A lightweight, fast, and stable window manager. It provides basic window decorations and management without consuming significant resources, making it ideal for containers.
    *   **Why this setup?** It's a standard, resource-efficient, and reliable combination. `Xvfb` + `x11vnc` is simpler for sharing one virtual display than servers like TigerVNC which manage their own sessions. `Fluxbox` provides essential WM functions without the bloat of full desktop environments (like Gnome, KDE, XFCE), saving RAM and CPU.
    *   **Alternatives:** `Openbox` is a very similar lightweight window manager and a good alternative to Fluxbox. While other lightweight WMs exist (IceWM, JWM), Fluxbox/Openbox offer a great balance of features, stability, and low resource use.

*   ### Caddy (Web Server - for Portal)
    *   Used in the `alt/`, `s-def/`, and `s-alt/` configurations. <!-- CHANGED -->
    *   Acts as a reverse proxy, providing secure (HTTPS, via Vast.ai's frontend) web access to internal services like VNC and logs.
    *   Configured via `Caddyfile`. Authenticates users via the `OPEN_BUTTON_TOKEN` provided by Vast.ai.

*   ### Runtime Download (Entrypoint Script)
    *   Used in the `s-def/` and `s-alt/` configurations (via `download_and_start.sh`).
    *   The `ENTRYPOINT` of the Docker container is set to this script.
    *   When the container starts, the script runs *first*. It checks if models (`/app/models/.downloaded`) and assets (`/app/dependencies/ffmpeg.exe`, `/app/dependencies/ffplay.exe`) exist.
    *   If items are missing, it runs the corresponding download commands (`download_models.py` or `wget`).
    *   After ensuring models/assets are present, it uses `exec` to replace itself with the `supervisord` process, which then starts the actual application and VNC/Caddy services.
    *   **Benefit:** Creates smaller Docker images, avoids Git LFS, reduces build time and storage.
    *   **Trade-off:** Increases the startup time for the *first* run of the container on Vast.ai.

---

## 3. Prerequisites

<!-- Section remains the same -->
1.  **Git:** Installed locally.
2.  **GitHub Account:** To host the repository and use Actions.
3.  **Docker Desktop (Optional):** Useful for local testing but not required for the pipeline.
4.  **DockerHub Account:** To store the built Docker images.
5.  **Vast.ai Account:** With credits to rent GPU instances.
6.  **VisoMaster Application Code:** The Python scripts and related files for VisoMaster.
7.  **VisoMaster Assets (Optional for `s-def`/`s-alt`):** Models, `ffmpeg.exe`, `ffplay.exe`, etc. If building `default` or `alt`, these must be downloaded locally first.

---

## 4. Repository Structure

<!-- Structure remains the same -->
```
your-repo-name/
├── VisoMaster/             # Application code (main.py, download_models.py, etc.)
├── dependencies/           # User assets (ONLY needed locally for default/alt builds)
├── default/                # Config: Default (VNC, Build-time)
│   ├── Dockerfile
│   ├── supervisord.conf
│   └── docker-compose.yml
├── alt/                    # Config: Alt (Portal, Build-time)
│   ├── Dockerfile
│   ├── Caddyfile
│   ├── supervisord.conf
│   └── docker-compose.yml
├── s-def/                  # Config: Small "Default" (NOW PORTAL, Runtime)
│   ├── Dockerfile
│   ├── Caddyfile           # <-- ADDED
│   ├── supervisord.conf    # <-- UPDATED
│   ├── download_and_start.sh
│   └── docker-compose.yml  # <-- UPDATED (Ref)
├── s-alt/                  # Config: Small Alt (Portal, Runtime)
│   ├── Dockerfile
│   ├── Caddyfile
│   ├── supervisord.conf
│   ├── download_and_start.sh
│   └── docker-compose.yml
├── .github/
│   └── workflows/          # GitHub Actions build workflows
│       ├── build-default.yml
│       ├── build-alt.yml
│       ├── build-s-def.yml
│       └── build-s-alt.yml
├── requirements.txt        # Shared Python dependencies
├── Install_Guide.ipynb     # Shared Internal guide / Diagnostics notebook
└── README.md               # This file
```

---

## 5. Setup Steps (Common)

<!-- Section remains the same -->
1.  **Clone Your Repo:** `git clone <your-repo-url>`
2.  **Add VisoMaster Code:** Place your application's Python scripts (e.g., `main.py`, `download_models.py`) inside the `VisoMaster/` folder.
3.  **Add Configuration Files:** Copy *all* provided configuration files and folders (`default/`, `alt/`, `s-def/`, `s-alt/`, `requirements.txt`, `Install_Guide.ipynb`, `README.md`, `.github/`) into your repository, matching the structure above.
4.  **Populate `dependencies/` (Conditional):**
    *   If you plan to build the `default` or `alt` configurations: Download required assets (like `ffmpeg.exe`, `ffplay.exe`, any *non*-model files needed at runtime) and place them in the `dependencies/` folder at the repository root.
    *   If you only plan to build `s-def` or `s-alt`: This folder can remain empty, as assets will be downloaded by the runtime script.
5.  **Review `requirements.txt`:** Ensure all necessary Python packages are listed.
6.  **GitHub Secrets:** In your GitHub repository settings (`Settings` > `Secrets and variables` > `Actions`), create two repository secrets:
    *   `DOCKERHUB_USERNAME`: Your Docker Hub username.
    *   `DOCKERHUB_TOKEN`: A Docker Hub access token (create one at [hub.docker.com](https://hub.docker.com/) under Account Settings > Security).
7.  **Commit and Push:**
    ```bash
    git add .
    git commit -m "Initial setup / Update s-def to use Portal"
    git push origin main
    ```

---

## 6. Build & Deployment Options (Choose One)

Select the option that best suits your needs.

*   ### Option 1: Default (`default/`) - VNC, Build-time Models/Assets
    *   **Characteristics:** Standard VNC access. Models included during build. Other assets copied from local `dependencies/` during build. Larger image, faster startup.
    *   **Build:** Triggered automatically on push to `main` by `.github/workflows/build-default.yml`. Builds from `default/Dockerfile`. Pushes tag `latest` and `<sha>`. **Requires local `dependencies/` folder to be populated.**
    *   **Vast.ai Launch:**
        *   Image: `your_dockerhub_username/visomaster:latest`
        *   Template: Jupyter Notebook
        *   Ports: Map Host Port `5901` to Container Port `5901`.
    *   **Access:** VNC Client (`<IP>:<HostPort>`), Jupyter Button.

*   ### Option 2: Alt (`alt/`) - Portal, Build-time Models/Assets
    *   **Characteristics:** Secure web portal access. Models included during build. Other assets copied from local `dependencies/` during build. Larger image, faster startup.
    *   **Build:** Trigger **manually** via GitHub Actions UI (`Actions` tab > `Build ALT (Portal) VisoMaster Image` > `Run workflow`). Builds from `alt/Dockerfile`. Pushes tag `portal-latest` and `portal-<sha>`. **Requires local `dependencies/` folder to be populated.**
    *   **Vast.ai Launch:**
        *   Image: `your_dockerhub_username/visomaster:portal-latest`
        *   Template: Jupyter Notebook
        *   Ports: Map Host Port `1111` (or your choice) to Container Port `11111`. **Do NOT map 5901.**
        *   Environment: Set `PORTAL_CONFIG` variable. Copy the JSON string below:
            ```json
            {"version":2,"port":11111,"services":[{"name":"VNC","uri":"/vnc/","proto":"http","rewrite":true,"auth":true},{"name":"AppLogs","uri":"/logs/visomaster_app.log","auth":true},{"name":"VNCLogs","uri":"/logs/x11vnc.log","auth":true},{"name":"CaddyLogs","uri":"/logs/caddy.log","auth":true},{"name":"LogBrowse","uri":"/logs/","auth":true}]}
            ```
    *   **Access:** Vast.ai "Open" Button (Portal), Jupyter Button.

*   ### Option 3: Small Default (`s-def/`) - Portal, Runtime Models/Assets <!-- CHANGED -->
    *   **Characteristics:** **Secure web portal access.** Models, `ffmpeg.exe`, `ffplay.exe` downloaded on first start. Smaller image, slower first startup. **Does not require local `dependencies/` folder.** <!-- CHANGED -->
    *   **Build:** Trigger **manually** via GitHub Actions UI (`Actions` tab > `Build SMALL DEFAULT VisoMaster Image` > `Run workflow`). Builds from `s-def/Dockerfile`. Pushes tag `small-latest` and `small-<sha>`.
    *   **Vast.ai Launch:**
        *   Image: `your_dockerhub_username/visomaster:small-latest`
        *   Template: Jupyter Notebook
        *   Ports: Map Host Port `1111` (or your choice) to Container Port `11111`. **Do NOT map 5901.** <!-- CHANGED -->
        *   Environment: Set `PORTAL_CONFIG` variable. Copy the JSON string below: <!-- CHANGED -->
            ```json
            {"version":2,"port":11111,"services":[{"name":"VNC","uri":"/vnc/","proto":"http","rewrite":true,"auth":true},{"name":"AppLogs","uri":"/logs/visomaster_app.log","auth":true},{"name":"VNCLogs","uri":"/logs/x11vnc.log","auth":true},{"name":"CaddyLogs","uri":"/logs/caddy.log","auth":true},{"name":"LogBrowse","uri":"/logs/","auth":true}]}
            ```
    *   **Access:** Vast.ai "Open" Button (Portal), Jupyter Button. (Allow extra time on first launch for downloads). <!-- CHANGED -->

*   ### Option 4: Small Alt (`s-alt/`) - Portal, Runtime Models/Assets
    *   **Characteristics:** Secure web portal access. Models, `ffmpeg.exe`, `ffplay.exe` downloaded on first start. Smaller image, slower first startup. **Does not require local `dependencies/` folder.**
    *   **Build:** Trigger **manually** via GitHub Actions UI (`Actions` tab > `Build SMALL ALT (Portal) VisoMaster Image` > `Run workflow`). Builds from `s-alt/Dockerfile`. Pushes tag `small-portal-latest` and `small-portal-<sha>`.
    *   **Vast.ai Launch:**
        *   Image: `your_dockerhub_username/visomaster:small-portal-latest`
        *   Template: Jupyter Notebook
        *   Ports: Map Host Port `1111` (or your choice) to Container Port `11111`. **Do NOT map 5901.**
        *   Environment: Set `PORTAL_CONFIG` variable. Copy the JSON string below:
            ```json
            {"version":2,"port":11111,"services":[{"name":"VNC","uri":"/vnc/","proto":"http","rewrite":true,"auth":true},{"name":"AppLogs","uri":"/logs/visomaster_app.log","auth":true},{"name":"VNCLogs","uri":"/logs/x11vnc.log","auth":true},{"name":"CaddyLogs","uri":"/logs/caddy.log","auth":true},{"name":"LogBrowse","uri":"/logs/","auth":true}]}
            ```
    *   **Access:** Vast.ai "Open" Button (Portal), Jupyter Button. (Allow extra time on first launch for downloads).

---

## 7. Using the Internal `Install_Guide.ipynb`

<!-- Section remains the same -->
*   **Access:** Available via the Jupyter Button on Vast.ai for *all* configurations. Navigate to `/app/VisoMaster/` and open the notebook.
*   **Purpose:** Validate setup, check GPU, view logs (check `/var/log/supervisor/` or `/var/log/portal/`), check service status (`supervisorctl status`), troubleshoot, run manual fixes. Essential post-launch tool.

---

## 8. Understanding the Configuration Files

<!-- Section remains the same -->
*   Each folder (`default/`, `alt/`, `s-def/`, `s-alt/`) contains the specific `Dockerfile`, `supervisord.conf`, and potentially `Caddyfile` or `download_and_start.sh` for that configuration.
*   The corresponding workflow file in `.github/workflows/` builds the image from that folder's Dockerfile and applies the correct Docker Hub tag.
*   Shared files (`requirements.txt`, `Install_Guide.ipynb`, `VisoMaster/`) are used by all builds.

---

## 9. Logging & Troubleshooting

<!-- Section remains the same, log paths are now consistent for portal builds -->
*   **GitHub Actions Logs:** Check build failures on the runner. Look for errors during `apt-get`, `conda install`, `pip install`, `COPY`, or model download steps. Check disk space cleanup effectiveness.
*   **DockerHub:** Verify image tags exist after a successful build workflow.
*   **Vast.ai Instance Logs (UI Button):** Check initial container startup errors. For `s-def`/`s-alt`, look for output from the `download_and_start.sh` script (download progress/errors). Check `supervisord` startup messages.
*   **Inside Container (`Install_Guide.ipynb`):** Use the notebook via the Jupyter interface for detailed diagnostics:
    *   Run `supervisorctl status` to see if all services (app, vnc, caddy, etc.) are `RUNNING`.
    *   Check logs in `/var/log/supervisor/` (core supervisor/xvfb/fluxbox logs) and `/var/log/portal/` (app, vnc, caddy logs for portal builds). Pay attention to `visomaster_app.log`, `visomaster_app_err.log`, and logs for VNC/Caddy.
    *   Verify GPU detection.
    *   Check file paths and existence of models/assets.

---

## 10. Conclusion

This repository now offers four distinct deployment paths for VisoMaster. The `default/` build provides direct VNC access, while `alt/`, `s-def/`, and `s-alt/` provide secure Instance Portal access. The `s-def/` and `s-alt/` configurations additionally download models and assets at runtime to avoid Git LFS and reduce image size. Choose the configuration that best fits your needs, follow the launch instructions carefully, and utilize the `Install_Guide.ipynb` for post-launch verification and troubleshooting.