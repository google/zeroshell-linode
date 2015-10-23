#!/bin/bash -e
# Copyright 2015 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Run within rescue mode on Linode to install ZeroShell:
# - First drive would be used for ZeroShell, 1GB required
# - Second drive would be used for temp files, 4GB required

ZEROSHELL="3.2.1"
KERNEL="3.4.90"

ZEROSHELL_DISK="/media/xvda"
INSTALL_DISK="/media/xvdb"
LOG="$INSTALL_DISK/install.log"
ISO_DISK="/media/iso"

KERNEL_FOLDER="linux-$KERNEL"
KERNEL_FILE="$KERNEL_FOLDER.tar.gz"
KERNEL_URL="http://www.kernel.org/pub/linux/kernel/v3.x/$KERNEL_FILE"
KERNEL_CONFIG=".config"
KERNEL_ZEROSHELL_CONFIG="zeroshell.kernel.config"

ISO_FILE="ZeroShell-$ZEROSHELL.iso"
ISO_URL="http://www.zeroshell.net/listing/$ISO_FILE"

# Useful scripts to show progress, not portable to other scrips
echo "Starting $ISO_FILE installation" | tee "$LOG"
function rsync_progress() {
  DESCRIPTION="$1"
  FROM="$2"
  TO="$3"
  LINES="$(find "$FROM" | wc --lines)"

  echo | tee --append "$LOG"
  echo "$DESCRIPTION" | tee --append "$LOG"
  rsync --archive --verbose "$FROM" "$TO" | pv --line-mode --size "$LINES" >> "$LOG"
}
function untar_progress() {
  DESCRIPTION="$1"
  FILE="$2"

  echo | tee --append "$LOG"
  echo "$DESCRIPTION" | tee --append "$LOG"
  pv "$FILE" | tar --extract --verbose --keep-old-files --gunzip --file - >> "$LOG"
}

echo "Make sure that both disks are mounted" | tee --append "$LOG"
mountpoint "$ZEROSHELL_DISK" || mount "$ZEROSHELL_DISK" >> "$LOG"
mountpoint "$INSTALL_DISK" || mount "$INSTALL_DISK" >> "$LOG"

rsync_progress "Save all the installation files for later reuse" \
"./" "$INSTALL_DISK"

echo "Download live CD, continue previous download" | tee --append "$LOG"
cd "$INSTALL_DISK"
wget --continue "$ISO_URL"

echo "Mount as read-only partition" | tee --append "$LOG"
mountpoint "$ISO_DISK" || (mkdir "$ISO_DISK" && mount "$ISO_FILE" "$ISO_DISK") >> "$LOG"

cd "$ZEROSHELL_DISK"
untar_progress "Unpack root parition" "$ISO_DISK/isolinux/rootfs"

rsync_progress "Unpack the rest of cdrom into rw partition" \
"$ISO_DISK/" "$ZEROSHELL_DISK/cdrom/"
rsync_progress "Copy initrd to the /boot folder" \
"$ISO_DISK/isolinux/initrd.img" "./boot/"

echo "And install all the required things for building a kernel" | tee --append "$LOG"
apt-get update | pv --line-mode --size 100 >> "$LOG"
yes "" | apt-get install --no-upgrade --yes build-essential libncurses5-dev \
| pv --line-mode --size 200 >> "$LOG"

echo "Download kernel sources, continue previous download"
cd "$INSTALL_DISK"
wget --continue "$KERNEL_URL"

untar_progress "Unpack kernel" "$KERNEL_FILE"

echo "Update config with Xen support" | tee --append "$LOG"
echo "http://wiki.xenproject.org/wiki/Mainline_Linux_Kernel_Configs" | tee --append "$LOG"
cd "$KERNEL_FOLDER"
echo "
CONFIG_XEN=y
CONFIG_XEN_BACKEND=n
CONFIG_HIGHMEM64G=y
" > "$KERNEL_CONFIG"

echo "Append zeroshell configuration from /proc/config.gz" | tee --append "$LOG"
cat "../$KERNEL_ZEROSHELL_CONFIG" | grep -v "CONFIG_HIGHMEM" >> "$KERNEL_CONFIG"

echo "Regenerate .config with all the dependencies of Xen" | tee --append "$LOG"
yes "" | make ARCH=i386 oldconfig | pv --line-mode --size 1000 >> "$LOG"

echo "Building the kernel and modules" | tee --append "$LOG"
make ARCH=i386 all | pv --line-mode --size 10000 >> "$LOG"

echo "Packaging into a convenient package" | tee --append "$LOG"
make ARCH=i386 tar-pkg | pv --line-mode --size 2000 >> "$LOG"

rsync_progress "Adding newly built kernel for booting" \
"$INSTALL_DISK/$KERNEL_FOLDER/tar-install/boot/" "$ZEROSHELL_DISK/boot/"

rsync_progress "Adding newly built modules and firmware" \
"$INSTALL_DISK/$KERNEL_FOLDER/tar-install/lib/" "$ZEROSHELL_DISK/cdrom/"

echo "Creating grub config for pv-grub to load"
mkdir "$ZEROSHELL_DISK/boot/grub" || true
echo "
timeout 5
title ZeroShell $ZEROSHELL ($KERNEL with Xen support)
root (hd0)
kernel /boot/vmlinuz-$KERNEL-ZS root=/dev/xvda rw
initrd /boot/initrd.img
" > "$ZEROSHELL_DISK/boot/grub/menu.lst"
mkdir "$ZEROSHELL_DISK/initrd" || true

echo "ZeroShell is installed successfully: $ZEROSHELL_DISK"
