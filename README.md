# Setup paperless-ngx with podman quadlets

This repo provides some podman quadlet files to setup paperless-ngx.

It was tested on a proxmox lxc container with debian 13. 
For other host systems you may need to make small adjustments.

## Requirements 

You need `podman` installed. 

## Autosetup with the install script

> [!WARNING]  
> This is still a work in progress. Try with your own risk.

```sh
curl -fsSL https://raw.githubusercontent.com/jomaway/paperless-ngx-quadlets/refs/heads/main/setup.sh | sh
```

## Manual setup

1. Copy the quadlet files from this repo to 
- `/etc/containers/systemd` if running as root.
- `~/.config/containers/systemd` if running as normal user.

2. Create two podman secrets:

-  `openssl rand -base64 32 | podman secret create paperless-db-password -`
- 
```bash
openssl rand -base64 32 | podman secret create paperless-db-password -
openssl rand -base64 32 | podman secret create  paperless-secret-key -
```

3. Change environment variables if required. (Optional)

4. Run `systemctl daemon-reload` to generate the service files.

5. Start the pod with `systemctl start paperless-pod.service`.

### The export service

1. Copy the `paperless-export.*` files from this repo to
- `/etc/systemd/system` if running as root.
- `~/.config/systemd/user` if running as normal user.

2. Run `systemctl daemon-reload` to generate the service files.

3. Start the timer with `systemctl start paperless-export.timer`.
