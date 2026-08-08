#!/usr/bin/env bash
set -euo pipefail

# InnovacoreOS - finish the lightweight LabWC desktop
# Debian 13 (Trixie) ARM64 / UTM
#
# IMPORTANT:
# 1. Run as the normal "innovacore" user, NOT with sudo.
# 2. This script backs up your existing desktop configs.
# 3. It does NOT reboot.
# 4. It does NOT modify greetd yet. We test the desktop first.

if [[ $EUID -eq 0 ]]; then
    echo "Run this as the innovacore user, not as root."
    exit 1
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/innovacore-desktop-backup-$STAMP"
mkdir -p "$BACKUP"

echo "==> Backing up existing configuration to:"
echo "    $BACKUP"

for d in labwc waybar foot fuzzel mako wlogout; do
    [[ -e "$HOME/.config/$d" ]] && cp -a "$HOME/.config/$d" "$BACKUP/"
done

echo "==> Installing remaining desktop components..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    labwc waybar foot fuzzel swaybg \
    mako-notifier swayidle swaylock wlogout \
    thunar file-roller \
    network-manager network-manager-gnome \
    pavucontrol playerctl \
    wl-clipboard grim slurp brightnessctl \
    xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
    xwayland spice-vdagent \
    gsettings-desktop-schemas libglib2.0-bin \
    adwaita-icon-theme hicolor-icon-theme \
    fonts-dejavu fonts-liberation2 fonts-noto-core fonts-font-awesome \
    dbus-user-session gvfs gvfs-backends \
    polkitd policykit-1 \
    firefox-esr geany

mkdir -p \
    "$HOME/.config/labwc" \
    "$HOME/.config/waybar" \
    "$HOME/.config/foot" \
    "$HOME/.config/fuzzel" \
    "$HOME/.config/mako" \
    "$HOME/.config/wlogout" \
    "$HOME/.config/environment.d" \
    "$HOME/.local/bin"

echo "==> Setting comfortable UI scaling..."
cat > "$HOME/.config/environment.d/90-innovacore.conf" <<'EOF'
GDK_SCALE=1.25
GDK_DPI_SCALE=1
QT_SCALE_FACTOR=1.25
QT_AUTO_SCREEN_SCALE_FACTOR=1
XCURSOR_SIZE=24
MOZ_ENABLE_WAYLAND=1
EOF

echo "==> Configuring Foot..."
cat > "$HOME/.config/foot/foot.ini" <<'EOF'
[main]
font=DejaVu Sans Mono:size=13
pad=8x8
term=xterm-256color

[scrollback]
lines=10000

[mouse]
hide-when-typing=yes

[colors]
foreground=ffffff
background=111318
regular0=1b1d23
regular1=ff6b6b
regular2=69db7c
regular3=ffd43b
regular4=74c0fc
regular5=da77f2
regular6=66d9e8
regular7=f1f3f5
bright0=868e96
bright1=ff8787
bright2=8ce99a
bright3=ffe066
bright4=91c8ff
bright5=e599f7
bright6=7ee7f2
bright7=ffffff
EOF

echo "==> Configuring Fuzzel..."
cat > "$HOME/.config/fuzzel/fuzzel.ini" <<'EOF'
[main]
font=DejaVu Sans:size=13
terminal=foot
prompt=Run: 
icon-theme=Adwaita
width=55
lines=12
horizontal-pad=18
vertical-pad=12
inner-pad=8
line-height=24
layer=overlay

[border]
width=1
radius=10

[colors]
background=111318ee
text=f1f3f5ff
match=74c0fcff
selection=2a2f3aff
selection-text=ffffffff
border=4b5563ff
EOF

echo "==> Configuring notifications..."
cat > "$HOME/.config/mako/config" <<'EOF'
font=DejaVu Sans 12
background-color=#111318ee
text-color=#f1f3f5ff
border-color=#4b5563ff
border-size=1
border-radius=10
padding=12
margin=12
width=380
height=120
default-timeout=5000
anchor=top-right
layer=overlay
max-visible=5
EOF

echo "==> Configuring Waybar..."
cat > "$HOME/.config/waybar/config.jsonc" <<'EOF'
{
  "layer": "top",
  "position": "top",
  "height": 38,
  "spacing": 6,
  "margin-top": 4,
  "margin-left": 6,
  "margin-right": 6,

  "modules-left": ["wlr/taskbar"],
  "modules-center": ["clock"],
  "modules-right": ["network", "pulseaudio", "cpu", "memory", "battery", "tray"],

  "wlr/taskbar": {
    "format": "{icon}",
    "icon-size": 20,
    "tooltip-format": "{title}",
    "on-click": "activate",
    "on-click-middle": "close"
  },

  "clock": {
    "format": "  %a %d %b   %H:%M  ",
    "tooltip-format": "<big>{:%Y %B}</big>\n<tt>{calendar}</tt>"
  },

  "network": {
    "format-wifi": "󰤨  {essid}",
    "format-ethernet": "󰈀  {ifname}",
    "format-disconnected": "󰤭  Offline",
    "tooltip-format": "{ifname}: {ipaddr}",
    "on-click": "nm-connection-editor"
  },

  "pulseaudio": {
    "format": "{icon} {volume}%",
    "format-muted": "󰝟 muted",
    "format-icons": ["󰕿", "󰖀", "󰕾"],
    "on-click": "pavucontrol",
    "on-click-right": "pactl set-sink-mute @DEFAULT_SINK@ toggle",
    "scroll-step": 5
  },

  "cpu": {
    "format": "CPU {usage}%",
    "interval": 2
  },

  "memory": {
    "format": "RAM {percentage}%",
    "interval": 2
  },

  "battery": {
    "format": "BAT {capacity}%",
    "format-charging": "BAT {capacity}% 󰂄",
    "states": {"warning": 30, "critical": 15}
  },

  "tray": {
    "icon-size": 20,
    "spacing": 8
  }
}
EOF

cat > "$HOME/.config/waybar/style.css" <<'EOF'
* {
  font-family: "DejaVu Sans", "Noto Sans", sans-serif;
  font-size: 13px;
  min-height: 0;
}

window#waybar {
  background: rgba(17, 19, 24, 0.96);
  color: #f1f3f5;
  border: 1px solid rgba(255,255,255,0.08);
  border-radius: 10px;
}

#clock, #network, #pulseaudio, #cpu, #memory, #battery, #tray, #taskbar {
  padding: 0 10px;
}

#clock { font-weight: bold; }

#taskbar button {
  padding: 0 7px;
  margin: 2px;
  border-radius: 7px;
}

#taskbar button.active {
  background: rgba(116, 192, 252, 0.18);
}

#battery.critical { color: #ff8787; }

tooltip {
  background: #111318;
  color: #f1f3f5;
  border: 1px solid #4b5563;
  border-radius: 8px;
}
EOF

echo "==> Creating wallpaper helper..."
cat > "$HOME/.local/bin/innovacore-wallpaper" <<'EOF'
#!/usr/bin/env bash
exec swaybg -c 080a0f
EOF
chmod +x "$HOME/.local/bin/innovacore-wallpaper"

echo "==> Creating screenshot helper..."
cat > "$HOME/.local/bin/innovacore-screenshot" <<'EOF'
#!/usr/bin/env bash
set -e
mkdir -p "$HOME/Pictures/Screenshots"
FILE="$HOME/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png"
grim -g "$(slurp)" "$FILE"
notify-send "Screenshot saved" "$FILE"
EOF
chmod +x "$HOME/.local/bin/innovacore-screenshot"

echo "==> Creating power menu..."
cat > "$HOME/.config/wlogout/layout" <<'EOF'
{
  "label": "lock",
  "action": "swaylock -f",
  "text": "Lock",
  "keybind": "l"
},
{
  "label": "logout",
  "action": "labwc --exit",
  "text": "Log out",
  "keybind": "e"
},
{
  "label": "reboot",
  "action": "systemctl reboot",
  "text": "Reboot",
  "keybind": "r"
},
{
  "label": "shutdown",
  "action": "systemctl poweroff",
  "text": "Shutdown",
  "keybind": "s"
}
EOF

cat > "$HOME/.config/wlogout/style.css" <<'EOF'
window {
  background-color: rgba(8,10,15,0.92);
}

button {
  color: #f1f3f5;
  background-color: #111318;
  border: 1px solid #343a40;
  border-radius: 12px;
  margin: 12px;
  font-size: 18px;
}

button:hover {
  background-color: #2a2f3a;
}
EOF

cat > "$HOME/.local/bin/innovacore-power" <<'EOF'
#!/usr/bin/env bash
exec wlogout -b 5
EOF
chmod +x "$HOME/.local/bin/innovacore-power"

echo "==> Configuring LabWC startup..."
cat > "$HOME/.config/labwc/autostart" <<'EOF'
#!/bin/sh

export PATH="$HOME/.local/bin:$PATH"
export GDK_SCALE="${GDK_SCALE:-1.25}"
export GDK_DPI_SCALE="${GDK_DPI_SCALE:-1}"
export QT_SCALE_FACTOR="${QT_SCALE_FACTOR:-1.25}"
export QT_AUTO_SCREEN_SCALE_FACTOR="${QT_AUTO_SCREEN_SCALE_FACTOR:-1}"
export XCURSOR_SIZE="${XCURSOR_SIZE:-24}"
export MOZ_ENABLE_WAYLAND=1

pgrep -x waybar >/dev/null 2>&1 || waybar &
pgrep -x mako >/dev/null 2>&1 || mako &
pgrep -x nm-applet >/dev/null 2>&1 || nm-applet --indicator &
pgrep -x swaybg >/dev/null 2>&1 || "$HOME/.local/bin/innovacore-wallpaper" &

systemctl --user start xdg-desktop-portal.service >/dev/null 2>&1 || true
systemctl --user start xdg-desktop-portal-wlr.service >/dev/null 2>&1 || true
systemctl --user start xdg-desktop-portal-gtk.service >/dev/null 2>&1 || true

if command -v spice-vdagent >/dev/null 2>&1; then
    pgrep -x spice-vdagent >/dev/null 2>&1 || spice-vdagent &
fi
EOF
chmod +x "$HOME/.config/labwc/autostart"

echo "==> Writing a complete LabWC keyboard configuration..."
cat > "$HOME/.config/labwc/rc.xml" <<'EOF'
<?xml version="1.0"?>
<labwc_config>
  <core>
    <decoration>server</decoration>
  </core>

  <keyboard>
    <keybind key="W-Return">
      <action name="Execute"><command>foot</command></action>
    </keybind>

    <keybind key="W-Space">
      <action name="Execute"><command>fuzzel</command></action>
    </keybind>

    <keybind key="W-E">
      <action name="Execute"><command>thunar</command></action>
    </keybind>

    <keybind key="W-L">
      <action name="Execute"><command>swaylock -f</command></action>
    </keybind>

    <keybind key="W-S">
      <action name="Execute"><command>innovacore-screenshot</command></action>
    </keybind>

    <keybind key="W-P">
      <action name="Execute"><command>innovacore-power</command></action>
    </keybind>

    <keybind key="W-A">
      <action name="Execute"><command>pavucontrol</command></action>
    </keybind>

    <keybind key="W-N">
      <action name="Execute"><command>nm-connection-editor</command></action>
    </keybind>

    <keybind key="W-Q">
      <action name="Close"/>
    </keybind>

    <keybind key="W-S-R">
      <action name="Reconfigure"/>
    </keybind>

    <keybind key="W-S-E">
      <action name="Exit"/>
    </keybind>
  </keyboard>
</labwc_config>
EOF

echo "==> Applying dark GTK settings..."
if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme 'Adwaita' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
fi

echo "==> Updating user directories..."
command -v xdg-user-dirs-update >/dev/null 2>&1 && xdg-user-dirs-update || true

echo
echo "============================================================"
echo " InnovacoreOS desktop setup is complete."
echo "============================================================"
echo
echo "Backup: $BACKUP"
echo
echo "Shortcuts:"
echo "  Super+Enter        Terminal"
echo "  Super+Space        Application launcher"
echo "  Super+E            File manager"
echo "  Super+L            Lock"
echo "  Super+S            Screenshot"
echo "  Super+P            Power menu"
echo "  Super+A            Audio controls"
echo "  Super+N            Network controls"
echo "  Super+Q            Close window"
echo "  Super+Shift+R      Reload LabWC"
echo "  Super+Shift+E      Exit LabWC"
echo
echo "Installed core apps:"
echo "  LabWC / Waybar / Foot / Fuzzel / Thunar"
echo "  Mako / swaybg / swaylock / wlogout"
echo "  NetworkManager / nm-applet / Pavucontrol"
echo "  Firefox ESR / Geany / File Roller"
echo "  wl-clipboard / grim / slurp"
echo "  xdg-desktop-portal / XWayland / SPICE agent"
echo
echo "NO REBOOT and NO greetd modification were performed."
echo "Log out and start LabWC again to test everything."
echo
echo "After confirming the desktop works, we can do the FINAL"
echo "greetd auto-login step separately."
