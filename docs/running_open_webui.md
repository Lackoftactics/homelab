# Running Open WebUI

There are two primary methods for running Open WebUI: using `docker run` and using `docker-compose`. Both methods have their advantages and are suited for different scenarios.

## Using `docker run`

The `docker run` command is a quick way to get an Open WebUI container running with a single command. This method is ideal for users who want to try out Open WebUI quickly or for simple, one-off deployments.

**Example:**

```bash
docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
```

This command downloads the latest Open WebUI image (if not already present) and starts a container named `open-webui`. It maps port 3000 on the host to port 8080 in the container, mounts a volume for persistent data, and ensures the container restarts automatically.

**Pros:**
- Quick and easy to get started.
- Requires only a single command.

**Cons:**
- Can become cumbersome for complex configurations.
- Less suitable for managing multiple services or dependencies.

**Example with API Key:**

If you need to integrate with services that require an API key, such as OpenRouter, you can pass it as an environment variable.

```bash
docker run -d -p 3000:8080 \
  -e OPENAI_API_KEY=YOUR_OPENROUTER_API_KEY \
  -v open-webui:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main
```

**Explanation of the command:**

*   `-d`: Runs the container in detached mode (in the background).
*   `-p 3000:8080`: Maps port 3000 on your host machine to port 8080 inside the container. You'll access Open WebUI via `http://localhost:3000`.
*   `-e OPENAI_API_KEY=YOUR_OPENROUTER_API_KEY`: Sets the `OPENAI_API_KEY` environment variable within the container. **Important:** Replace `YOUR_OPENROUTER_API_KEY` with your actual OpenRouter API key.
*   `-v open-webui:/app/backend/data`: Mounts a Docker volume named `open-webui` to the `/app/backend/data` directory inside the container. This ensures that your Open WebUI data (like user information and settings) persists even if the container is removed or updated. If the volume `open-webui` doesn't exist, Docker will create it.
*   `--name open-webui`: Assigns the name `open-webui` to the container, making it easier to manage (e.g., `docker stop open-webui`).
*   `--restart always`: Configures the container to automatically restart if it stops or if the Docker daemon restarts. This is useful for ensuring Open WebUI is always running.
*   `ghcr.io/open-webui/open-webui:main`: Specifies the Docker image to use. This pulls the `main` tag (often the latest stable version) of the Open WebUI image from the GitHub Container Registry.

## Using `docker-compose`

`docker-compose` is a tool for defining and managing multi-container Docker applications. It uses a YAML file (typically `docker-compose.yml`) to configure the application's services, networks, and volumes. This method is generally preferred for long-term management, especially in a homelab environment, as it provides better organization and reproducibility.

Even for a single container application like Open WebUI, `docker-compose` can be beneficial for managing more complex configurations, environment variables, and dependencies in a structured way.

**Example `docker-compose.yml`:**

```yaml
version: '3.8'

services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:main # Specifies the Docker image to use
    container_name: open-webui
    ports:
      - "3000:8080" # Exposes port 3000 on the host, mapped to 8080 in the container
    volumes:
      - /mnt/user/appdata/open-webui:/app/backend/data # Mounts a host path. Replace /mnt/user/appdata/open-webui with your desired host path.
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434 # Example: URL for Ollama if running locally
      - OPENAI_API_KEY=YOUR_OPENROUTER_API_KEY # Replace YOUR_OPENROUTER_API_KEY with your actual key
      # Add other environment variables as needed
    restart: always # Ensures the container restarts if it stops
    extra_hosts:
      - "host.docker.internal:host-gateway" # Ensures host.docker.internal resolves for Ollama, etc.
```

### Understanding Volume Mapping: Named Volumes vs. Host Paths

For data persistence, Docker offers two main types of volume mapping: named volumes and host path (bind) mounts. The `docker-compose.yaml` example above uses a host path mount.

1.  **Named Volumes:**
    *   **How it works:** Docker manages the storage location on the host system (typically within `/var/lib/docker/volumes/your-volume-name/_data`). You refer to the volume by its name.
    *   **Ease of use:** Simpler if you don't need to know the exact storage location on the host. Docker handles it for you.
    *   **Syntax:** `volume-name:/path/in/container` (e.g., `open-webui-data:/app/backend/data`). You would also define the named volume under a top-level `volumes:` key in your `docker-compose.yaml`.

2.  **Host Path (Bind) Mounts:**
    *   **How it works:** You specify an exact file or directory path from your host machine to be mounted into the container.
    *   **Syntax:** `/path/on/host:/path/in/container` (e.g., `/mnt/user/appdata/open-webui:/app/backend/data`).

3.  **Benefits of Host Paths for Homelab Users:**
    *   **Direct Data Access:** You can easily browse, manage, and back up the application data (like settings, user accounts, etc.) directly from your host system because you know exactly where it is located.
    *   **Centralized Appdata:** This approach aligns well with common homelab practices where users often prefer to organize all persistent application data under a specific directory structure on their server (e.g., `/mnt/user/appdata/` or `/opt/appdata/`).
    *   **Easier Backups:** Integrating with existing backup solutions (e.g., scripts or tools that back up specific host directories) becomes straightforward.
    *   **Permissions Control:** Allows for more direct control over file ownership and permissions from the host. However, this can sometimes introduce complexity if the user and group IDs inside the container don't align with host permissions. It's important to ensure the Docker process or the container user has the necessary permissions to read/write to the host path.

The choice between named volumes and host paths depends on your specific needs and preferences. For many homelab users, the transparency and control offered by host path mounts make them a popular choice.

**Important Note for Host Path Mounts:**

*   **Directory Creation:** You must ensure that the host path you specify (e.g., `/mnt/user/appdata/open-webui`) exists on your server *before* starting the container. If it doesn't exist, Docker may try to create it, but this can lead to permission issues. It's best to create it manually (e.g., `mkdir -p /mnt/user/appdata/open-webui`).
*   **Permissions:** The user running the Docker daemon (or the user ID the container runs as, if specified) needs read and write permissions to the host directory. If you encounter permission errors, you may need to adjust the ownership or permissions of the host directory (e.g., using `chown` or `chmod`). For Open WebUI, the container typically runs as a non-root user (UID 1000, GID 1000 by default in many community images, but this can vary). You might need to set the ownership of your host directory accordingly, for example: `sudo chown -R 1000:1000 /mnt/user/appdata/open-webui` if that UID/GID matches the container's user.

To start Open WebUI using `docker-compose`, you would navigate to the directory containing the `docker-compose.yml` file and run:

```bash
docker-compose up -d
```

**Pros:**
- Better organization and readability for configurations.
- Easier to manage complex setups and multiple services.
- Configuration is version-controllable (as the YAML file can be added to git).
- Ideal for long-term deployments and homelab setups.

**Cons:**
- Requires an additional tool (`docker-compose`) to be installed.
- Involves creating and managing a YAML file.

**Recommendation for Homelab Users:**

For homelab environments, using `docker-compose` is generally recommended over a simple `docker run` command. It allows for easier management of the application's configuration (which is stored in a readable YAML file), and simplifies starting, stopping, and updating the service. It's also better for managing multiple services if your homelab grows.

**How to use the `docker-compose.yaml`:**

1.  Save the YAML content from the example above into a file named `docker-compose.yaml` in a dedicated directory on your homelab server (e.g., `/opt/open-webui/docker-compose.yaml`).
2.  Open a terminal and navigate to that directory (e.g., `cd /opt/open-webui`).
3.  Run the command `docker-compose up -d`. This will download the Open WebUI image (if not already present) and start the container in detached mode (running in the background).
4.  To stop the service, navigate to the same directory in your terminal and run `docker-compose down`. This will stop and remove the container. Your data will remain safe in the `open-webui` volume.
5.  To update the image to the latest version, you can run `docker-compose pull` (to fetch the newest image) followed by `docker-compose up -d` (to recreate the container with the new image).

In summary, `docker run` is great for a quick start, while `docker-compose` offers a more robust and manageable solution for long-term use and more complex scenarios.

## Final Information

Once started, Open WebUI should be accessible in your web browser at `http://<your-homelab-server-ip>:3000` (replace `<your-homelab-server-ip>` with the actual IP address of your server).

**Important Reminder:** Ensure you have replaced `YOUR_OPENROUTER_API_KEY` in either the `docker run` command or the `docker-compose.yaml` file with your actual OpenRouter API key before starting the container.
