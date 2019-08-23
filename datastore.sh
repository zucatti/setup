apt-get install -y lvm2
systemctl start lvm2-lvmetad.socket
pvcreate /dev/{$1}
vgcreate lvm /dev/$1
lvcreate -l 100%FREE -n storage lvm
mkfs -t ext4 /dev/lvm/storage
echo "/dev/mapper/lvm-storage /mnt ext4 rw,relatime 0 0" >> /etc/fstab
mount -a
sed -i -e 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf
