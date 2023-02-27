set -eu
echo "===    bin   -> FT65SYNC ==="
rsync -rchvu bin/* ~/wh/OneDrive/FxT-65/FT65SYNC/
mount -t drvfs f: /mnt/sd/
echo "=== SDカード -> FT65SYNC ==="
rsync -rthvuc /mnt/sd/ /home/ponzu840w/wh/OneDrive/FxT-65/FT65SYNC/
echo "=== FT65SYNC -> SDカード ==="
rsync -rthvuc /home/ponzu840w/wh/OneDrive/FxT-65/FT65SYNC/ /mnt/sd/
umount /mnt/sd

