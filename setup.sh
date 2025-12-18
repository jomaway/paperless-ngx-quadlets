#!/bin/bash
# Wrap in a block to prevent partial execution
{
    set -euo pipefail

    check_environment() {
        # Determine if we should use System-wide or User-specific paths
        if [ "$EUID" -eq 0 ]; then
            QUADLET_DIR="/etc/containers/systemd"
            UNITS_DIR="/etc/systemd/system"
            SYSTEMD_CMD="systemctl"
            echo "Running as Root or inside LXC. Target: $QUADLET_DIR"
        else
            QUADLET_DIR="$HOME/.config/containers/systemd"
            UNITS_DIR="$HOME/.config/systemd/user"
            SYSTEMD_CMD="systemctl --user"
            echo "Running as standard user. Target: $QUADLET_DIR"
        fi

        mkdir -p "$QUADLET_DIR"
    }

    create_directories() {
        # Define the base data path
        DATA_ROOT="/var/lib/paperless"

        if [ "$EUID" -eq 0 ]; then
            # Create as root
            mkdir -p "$DATA_ROOT"/{consume,export}
            # If running rootless podman inside LXC, you'll need to chown to the subuid
            # Otherwise, standard root permissions work:
            chmod -R 755 "$DATA_ROOT"
        else
            # Create in home dir for rootless
            DATA_ROOT="$HOME/paperless"
            mkdir -p "$DATA_ROOT"/{consume,export}
        fi
    }

    download_files() {
        REPO_BASE_URL="https://raw.githubusercontent.com/jomaway/paperless-ngx-quadlets/refs/heads/main/"
        # List all your files here
        QUADLET_FILES=("paperless.pod" "paperless-db.container" "paperless-app.container" "paperless-broker.container" "paperless.env")
        EXPORT_FILES=("paperless-export.timer" "paperless-export.service")

        echo "--- Start downloading files ---"

        for FILE in "${QUADLET_FILES[@]}"; do
            echo "Downloading $FILE..."
            curl -fsSL "$REPO_BASE_URL/$FILE" -o "$QUADLET_DIR/$FILE"
        done

        for FILE in "${EXPORT_FILES[@]}"; do
            echo "Downloading $FILE..."
            curl -fsSL "$REPO_BASE_URL/$FILE" -o "$UNITS_DIR/$FILE"
        done
    }

    create_secrets() {
        echo "--- Setup secrets ---"

        # Ask user to enter the db password
        read -rs -p "Enter Paperless DB Password: " DB_PASS
        echo ""
        SECRET_KEY=$(head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 128)
        echo "Generated 128-byte Secret Key automatically."

        if [[ -z "$DB_PASS" || -z "$SECRET_KEY" ]]; then
            echo "Error: Passwords cannot be empty."
            exit 1
        fi

        # Create secrets safely
         printf "%s" "$DB_PASS" | podman secret create --replace paperless-db-password -
         printf "%s" "$SECRET_KEY" | podman secret create --replace paperless-secret-key -

        # Cleanup variables
        unset DB_PASS
        unset SECRET_KEY

        echo "Secrets successfully stored in Podman."
    }

    prepull_OCI_images() {
        local IMAGES=(
            "ghcr.io/paperless-ngx/paperless-ngx:latest"
            "docker.io/library/redis:8"
            "docker.io/library/postgres:18"
        )

        for IMG in "${IMAGES[@]}"; do
            if ! podman image exists "$IMG"; then
                echo "LOG: Image $IMG not found locally. Pulling..."
                podman pull "$IMG"
            else
                echo "LOG: Image $IMG already exists. Skipping pull."
            fi
        done
    }

    echo "--- Starting Paperless-ngx podman quadlet setup ---"

    check_environment
    create_directories
    download_files
    create_secrets
    prepull_OCI_images

    echo "Reloading systemd..."
    ${SYSTEMD_CMD} daemon-reload

    echo "------------------------------------------------"
    echo "Setup Complete!"
    echo "The .container and .pod files are ready in $QUADLET_DIR"
    echo "To start the application, run:"
    echo "  $SYSTEMD_CMD start paperless-pod.service or reboot your system."
    echo "------------------------------------------------"
    echo "To start the export timer, run:"
    echo "  $SYSTEMD_CMD enable paperless-export.service."
    echo "------------------------------------------------"
}
