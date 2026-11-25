Paramètres
ZRAM_SIZE="ram / 2"
ZRAM_ALGO="zstd"
ZRAM_FSTYPE="swap"
ZRAM_PRIORITY=100
CONFIG_FILE="/etc/systemd/zram-generator.conf"
PACKAGE="systemd-zram-generator"
ZRAM_UNIT="systemd-zram-setup@zram0.service"
