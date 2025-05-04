# GodViso - Dockerized VisoMaster Environments

This repository, maintained by **remphan1618**, provides various Docker configurations for running the [VisoMaster](https://github.com/joshsylvia/VisoMaster) application. Each configuration bundles VisoMaster with different tools (like Jupyter Lab, KasmVNC, Caddy) to suit various needs.

Docker images are automatically built and pushed to Docker Hub via GitHub Actions upon changes to the respective configuration files or the main `download_and_start.sh` script.

**Current Date (Reflected in last update check):** 2025-05-03

## Prerequisites

*   **Docker:** You need Docker installed and running on your system. [Get Docker](https://docs.docker.com/get-docker/)

## Configurations Overview

The following configurations are available, each built into a separate Docker image tag:

| Configuration | Tag       | VisoMaster | Jupyter Lab | KasmVNC GUI | Caddy Proxy/Portal | Description                                                                 |
| :------------ | :-------- | :--------- | :---------- | :---------- | :----------------- | :-------------------------------------------------------------------------- |
| **Default**   | `default` | ✅         | ✅          | ❌          | ✅ (Proxy Only)    | Standard setup with VisoMaster and Jupyter Lab, accessible via Caddy proxy. |
| **Alternate** | `alt`     | ✅         | ✅          | ✅          | ✅ (Portal)        | Includes VisoMaster, Jupyter Lab, and a KasmVNC desktop GUI. Caddy portal.  |
| **Small Def** | `s-def`   | ✅         | ❌          | ✅          | ❌                 | Minimal setup with VisoMaster in a KasmVNC desktop GUI. Direct access.      |
| **Small Alt** | `s-alt`   | ✅         | ❌          | ✅          | ✅ (Portal)        | Minimal setup with VisoMaster in a KasmVNC desktop GUI. Caddy portal.       |

## Getting the Images

Pre-built images are available on Docker Hub:

**[https://hub.docker.com/r/remphan1618/godviso](https://hub.docker.com/r/remphan1618/godviso)**

You can pull a specific image using its tag:

```bash
docker pull remphan1618/godviso:default
docker pull remphan1618/godviso:alt
docker pull remphan1618/godviso:s-def
docker pull remphan1618/godviso:s-alt
```

## Running the Containers

Each container uses a shared entrypoint script (`download_and_start.sh`) that automatically downloads necessary dependencies (like FFmpeg) and VisoMaster models on the first run if they are not present in mounted volumes.

**Important:** It is highly recommended to use Docker volumes to persist downloaded models, dependencies, and logs between container runs.

---

### 1. Default (`:default`)

Provides VisoMaster and Jupyter Lab, proxied by Caddy.

**Run Command:**

```bash
docker run -d --rm \
  --name godviso-default \
  -p 11111:11111 \
  -p 8888:8888 \
  -v godviso-models:/app/models \
  -v godviso-deps:/app/dependencies \
  -v godviso-logs:/app/logs \
  remphan1618/godviso:default
```

**Access:**

*   **Caddy Proxy:** `http://localhost:11111` (Provides access to services below)
    *   VisoMaster App: `http://localhost:11111/visomaster/`
    *   Jupyter Lab: `http://localhost:11111/jupyter/` (Also directly via `http://localhost:8888`)
    *   Logs: `http://localhost:11111/logs/`
*   **Jupyter Lab (Direct):** `http://localhost:8888` (No token required)

---

### 2. Alternate (`:alt`)

Provides VisoMaster, Jupyter Lab, and a KasmVNC desktop GUI, accessed via a Caddy portal.

**Run Command:**

```bash
docker run -d --rm \
  --name godviso-alt \
  -p 11111:11111 \
  -p 8888:8888 \
  -v godviso-models:/app/models \
  -v godviso-deps:/app/dependencies \
  -v godviso-logs:/app/logs \
  remphan1618/godviso:alt
```

**Access:**

*   **Caddy Portal:** `http://localhost:11111`
    *   Click "KasmVNC GUI" link (accesses `/gui/`) to reach the VisoMaster desktop.
    *   Click "View Logs" link (accesses `/logs/`).
*   **Jupyter Lab (Direct):** `http://localhost:8888` (No token required)

---

### 3. Small Default (`:s-def`)

Provides VisoMaster within a KasmVNC desktop GUI. Direct access to KasmVNC.

**Run Command:**

```bash
docker run -d --rm \
  --name godviso-s-def \
  -p 8443:8443 \
  -v godviso-models:/app/models \
  -v godviso-deps:/app/dependencies \
  -v godviso-logs:/app/logs \
  remphan1618/godviso:s-def
```

**Access:**

*   **KasmVNC GUI:** `http://localhost:8443`

---

### 4. Small Alternate (`:s-alt`)

Provides VisoMaster within a KasmVNC desktop GUI, accessed via a Caddy portal.

**Run Command:**

```bash
docker run -d --rm \
  --name godviso-s-alt \
  -p 11111:11111 \
  -v godviso-models:/app/models \
  -v godviso-deps:/app/dependencies \
  -v godviso-logs:/app/logs \
  remphan1618/godviso:s-alt
```

**Access:**

*   **Caddy Portal:** `http://localhost:11111`
    *   Click "KasmVNC GUI" link (accesses `/gui/`) to reach the VisoMaster desktop.
    *   Click "View Logs" link (accesses `/logs/`).

---

### Volume Persistence Notes

*   `-v godviso-models:/app/models`: Persists downloaded AI models. Prevents re-downloading on container restart.
*   `-v godviso-deps:/app/dependencies`: Persists downloaded dependencies like FFmpeg.
*   `-v godviso-logs:/app/logs`: Persists logs generated by supervisord, Caddy, KasmVNC, and VisoMaster.
*   You can replace `godviso-models`, `godviso-deps`, `godviso-logs` with host paths if preferred (e.g., `-v ./my-models:/app/models`), but named volumes are generally recommended.

## Building Locally (Optional)

If you want to build the images yourself:

1.  Clone this repository: `git clone https://github.com/remphan1618/GodViso.git`
2.  Navigate to the repository root: `cd GodViso`
3.  Run the build command, specifying the Dockerfile for the desired configuration:

    ```bash
    # Example for 'default' config
    docker build -t my-godviso:default -f ./default/Dockerfile .

    # Example for 's-alt' config
    docker build -t my-godviso:s-alt -f ./s-alt/Dockerfile .
    ```

## How It Works

*   **Entrypoint:** The `download_and_start.sh` script runs first. It ensures necessary directories exist and downloads models/dependencies if they aren't found (e.g., in mounted volumes).
*   **Process Management:** `supervisord` is used within the container to manage the different services (VisoMaster, Caddy, KasmVNC, Xvfb) based on the specific configuration's `supervisord.conf`.
*   **GUI:** KasmVNC provides a web-based VNC interface to a virtual desktop where the VisoMaster GUI runs (in relevant configurations).
*   **Proxy/Portal:** Caddy acts as a reverse proxy and/or serves a simple HTML portal page (in relevant configurations).

## Contributing

(Add contribution guidelines if desired)

## License

(Specify a license if desired, e.g., MIT)