rm -rf test.img
mkdir -p mnt

truncate -s1G test.img

mke2fs -t ext4 -b 4096 test.img

mount test.img mnt

 dd if=/dev/zero bs=1M count=64 of=mnt/convert_space_holder status=noxfer

# Use up 800MiB first
for i in $(seq 1 4); do
        fallocate -l 200M "mnt/file$i"
done

# Then add 5MiB for above files. These 5 MiB will be allocated near the very
# end of the fs, to confuse btrfs-convert
for i in $(seq 1 4); do
        fallocate -l 205M "mnt/file$i"
done

umount mnt
