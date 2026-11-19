#!/usr/bin/env bash
# One-time: make the server deploy every green build of main by itself
# (checks every 2 minutes). Safe to run again. Logs: journalctl -u up-autodeploy
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
DIR=/opt/up/app/server/deploy
chmod +x "$DIR/autodeploy.sh" "$DIR/update.sh"

cat > /etc/systemd/system/up-autodeploy.service <<UNIT
[Unit]
Description=AppDate: deploy the latest green build of main
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$DIR/autodeploy.sh
UNIT

cat > /etc/systemd/system/up-autodeploy.timer <<UNIT
[Unit]
Description=AppDate: check for a new build every 2 minutes

[Timer]
OnBootSec=1min
OnUnitActiveSec=2min

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now up-autodeploy.timer
systemctl start up-autodeploy.service || true
systemctl list-timers up-autodeploy.timer --no-pager
echo "autodeploy installed; deployed: $(cat /var/lib/up/.deployed-release 2>/dev/null || echo none)"
