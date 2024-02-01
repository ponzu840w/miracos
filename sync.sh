set -eu

drive_letter=$1
echo "drive:"${drive_letter}

echo "===    bin   -> FT65SYNC ==="
rsync -rchvu --omit-dir-times bin/* /home/ponzu840w/wh/OneDrive/FxT-65/FT65SYNC/
mount -t drvfs ${drive_letter}: /mnt/sd/
#echo "=== SDカード -> FT65SYNC ==="
#rsync -rthvuc /mnt/sd/ /home/ponzu840w/wh/OneDrive/FxT-65/FT65SYNC/
echo "=== FT65SYNC -> SDカード ==="
rsync -rthvuc --omit-dir-times /home/ponzu840w/wh/OneDrive/FxT-65/FT65SYNC/ /mnt/sd/
umount /mnt/sd

