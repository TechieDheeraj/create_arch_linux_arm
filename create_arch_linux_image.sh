#!/bin/bash
set -e
cd ~

# === CONFIGURATION ===
IMG=~/archroot-64G.img
SIZE=64G
ARCH_TAR=~/ArchLinuxARM-aarch64-latest.tar.gz
ARCHROOT=/mnt/archroot

if [ ! -f "$ARCH_TAR" ]; then
  curl -o $ARCH_TAR -L http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz
fi
# === REQUIREMENTS ===
sudo apt update
sudo apt install -y lsof parted dosfstools e2fsprogs grub-efi-arm64 vim tmux libarchive-tools locales

sudo bash -c 'echo "LC_ALL=en_US.UTF-8" >> /etc/environment'
sudo bash -c 'echo "LANG=en_US.UTF-8" > /etc/locale.conf'
sudo locale-gen en_US.UTF-8

# === CREATE DISK IMAGE ===
echo "==> Creating $SIZE disk image at $IMG..."
fallocate -l $SIZE "$IMG"

# === SETUP LOOP DEVICE ===
echo "==> Attaching loop device..."
LOOP=$(sudo losetup --find --show --partscan "$IMG")
echo "Attached to $LOOP"

# === PARTITION THE IMAGE ===
echo "==> Partitioning..."
sudo parted "$LOOP" --script \
  mklabel gpt \
  mkpart ESP fat32 1MiB 401MiB \
  set 1 esp on \
  mkpart primary ext4 402MiB 1402MiB \
  mkpart primary ext4 1403MiB 100%

# === FORMAT FILESYSTEMS ===
EFI=${LOOP}p1
BOOT=${LOOP}p2
ROOT=${LOOP}p3
echo "==> Formatting partitions..."
sudo mkfs.vfat -F32 "$EFI"
sudo mkfs.ext4 "$BOOT"
sudo mkfs.ext4 "$ROOT"

# === MOUNT FILESYSTEMS ===
echo "==> Mounting partitions..."
sudo mkdir -p "$ARCHROOT"
sudo mount "$ROOT" "$ARCHROOT"
sudo mkdir -p "$ARCHROOT/boot"
sudo mount "$BOOT" "$ARCHROOT/boot"
sudo mkdir -p "$ARCHROOT/boot/efi"
sudo mount "$EFI" "$ARCHROOT/boot/efi"

# === DOWNLOAD AND EXTRACT ROOTFS ===
cd "$ARCHROOT"
echo "==> Copying Arch Linux ARM rootfs..."
sudo cp "$ARCH_TAR" .
echo "==> Extracting rootfs..."
sudo bsdtar -xpf "$(basename $ARCH_TAR)" -C "$ARCHROOT"
sync
sudo rm "$(basename $ARCH_TAR)"

# === MOUNT SYSTEM DIRS FOR CHROOT ===
for dir in dev proc sys run; do
  sudo mount --bind /$dir "$ARCHROOT/$dir"
done

# === INSTALL GRUB AND OS PACKAGES INSIDE CHROOT ===
echo "==> Installing bootloader and base packages..."
sudo chroot "$ARCHROOT" /bin/bash -c "
  pacman-key --init && pacman-key --populate archlinuxarm
  pacman -Sc --noconfirm
  pacman -Syy --noconfirm
  pacman -Syu --noconfirm
  pacman -Sy --noconfirm grub efibootmgr dosfstools linux-aarch64 base tmux git wget nmap
  git clone https://github.com/TechieDheeraj/.dotfiles.git
  grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=GRUB --removable --no-nvram
  grub-mkconfig -o /boot/grub/grub.cfg
  mkinitcpio -p linux-aarch64
"
# To fix
if [ -f "/mnt/archroot/boot/grub/grub.cfg" ]; then
  UUID=$(sudo blkid -s UUID -o value "$ROOT") && sudo sed -i "s|root=/dev/loop0p3|root=UUID=$UUID|g" /mnt/archroot/boot/grub/grub.cfg
  sudo sed -i $'/^[[:space:]]*linux[[:space:]]\\+.*root=UUID=/a\\\tinitrd /initramfs-linux.img' /mnt/archroot/boot/grub/grub.cfg
  echo "✅ Bootable Arch ARM image ready at: $IMG"
else
  echo "❌ Failed to Create Bootable Arch ARM image: $IMG"
  rm $IMG
fi

sudo pkill gpg-agent
cd ~
# === CLEANUP ===
echo "==> Cleaning up..."
for dir in dev proc sys run; do
  sudo umount -lf "$ARCHROOT/$dir"
done
sudo umount -R "$ARCHROOT/boot/efi"
sudo umount -R "$ARCHROOT/boot"
sudo umount -R "$ARCHROOT"
sudo losetup -d "$LOOP"
