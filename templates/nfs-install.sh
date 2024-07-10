apt install -y nfs-kernel-server
mkdir -p /srv/domino
mkfs.ext4 /dev/disk/by-id/google-nfs
UUID=$(blkid /dev/disk/by-id/google-nfs -s UUID -o value)
echo UUID=$UUID /srv/domino ext4 defaults 0 2 >> /etc/fstab
systemctl daemon-reload
mount /srv/domino
chmod 777 /srv/domino
echo '/srv/domino 10.0.0.0/255.0.0.0(rw,async,no_root_squash)' >> /etc/exports
systemctl enable nfs-kernel-server --now
sleep 5
/etc/init.d/nfs-kernel-server restart
