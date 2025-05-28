Make sure blkid is matching correctly for /boot and / in /boot/grub.cfg and initrd is mentioned too

once img is mounted

TEST new image after creating the img file (on mac I use):

> qemu-system-aarch64 \
  -machine virt,accel=hvf,secure=off \
  -cpu host \
  -m 4096 \
  -bios /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
  -drive file=<IMG FILE>,format=raw,if=virtio \
  -serial mon:stdio


Now If you want to try on parallels, need to convert img file to hdd:

> qemu-img convert -O parallels archroot-22G.img arch.hdd

Now mv arch.hdd into hds file '~/Parallels/Other Linux.pvm/Other Linux-0.hdd/Other Linux-0.hdd.0.{5fbaabe3-6958-40ff-92a7-860e329aab41}.hds'
Find the size in bytes of hds file:
> stat -f%z Other\ Linux-0.hdd.0.\{5fbaabe3-6958-40ff-92a7-860e329aab41\}.hds

Open DiskDescriptor.xml and Note:
    Under <Disk_Parameters>:
    1. <LogicSectorSize>512</LogicSectorSize>
    2. Replace   <Disk_size>4413456384</Disk_size>, with actual size you notes above in stat file and also below
    <End>4413456384</End> in <Storage> in <StorageData>
    3. Replace  <Cylinders>8620032</Cylinders> in <Disk_Parameters> with Value of (Disk_size / LogicSectorSize)




