[Unit]
Description=ACCWeb - Assetto Corsa Competizione Dedicated Server Manager
After=network.target

[Service]
Type=simple
User=__ACC_USER__
Group=__ACC_USER__
WorkingDirectory=__ACCWEB_DIR__
Environment=WINEPREFIX=__WINE_PREFIX__
Environment=WINEARCH=win64
Environment=WINEDEBUG=-all
Environment=WINEDLLOVERRIDES=mscoree,mshtml=
ExecStart=/usr/bin/xvfb-run -a -s "-screen 0 1024x768x24" __ACCWEB_DIR__/accweb
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
KillMode=control-group

[Install]
WantedBy=multi-user.target
