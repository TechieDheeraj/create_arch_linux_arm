IMG=$1

qemu-system-aarch64 \
  -machine virt,accel=hvf,secure=off \
  -cpu host \
  -m 4096 \
  -bios /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
  -drive file=$IMG,format=raw,if=virtio \
  -serial mon:stdio
