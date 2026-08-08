{
    "layer": "top",
    "position": "top",
    "height": 32,
    "spacing": 6,

    "modules-left": [
        "wlr/taskbar"
    ],

    "modules-center": [
        "clock"
    ],

    "modules-right": [
        "network",
        "cpu",
        "memory",
        "tray"
    ],

    "wlr/taskbar": {
        "format": "{icon}",
        "icon-size": 20,
        "tooltip-format": "{title}",
        "on-click": "activate",
        "on-click-middle": "close"
    },

    "clock": {
        "format": "󰥔  %a %d %b  %H:%M",
        "tooltip": false
    },

    "network": {
        "format-wifi": "󰖩  {essid}",
        "format-ethernet": "󰈀  {ipaddr}",
        "format-disconnected": "󰖪  Offline",
        "tooltip-format": "{ifname}: {ipaddr}"
    },

    "cpu": {
        "format": "󰍛  {usage}%"
    },

    "memory": {
        "format": "󰘚  {percentage}%"
    },

    "tray": {
        "icon-size": 18,
        "spacing": 6
    }
}
