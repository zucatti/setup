umount /mnt
vgextend lvm $1
lvextend -l +100%Free /dev/lvm/storage
resize2fs /dev/lvm/storage
mount -a
