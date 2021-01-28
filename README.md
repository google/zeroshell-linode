This is not an official Google product.

zeroshell-linode
================

Automate running ZeroShell (http://zeroshell.org) under Xen (Linode in particular)

If you're asking yourself how to run ZeroShell on Linode (or Xen in general)
I've got an answer for you, an automted script for installation.

Biggest problem with ZeroShell 3.2.1 is that it does not have Xen support
compiled in. So we need to recompile a kernel. Another thing is that
Linode pv-grub only supports /boot/grub/menu.lst file, which we need to
create on the root filesystem. And Linode does not like multipartitioned disks.

Installation ZeroShell 3.2.1 onto Linode
========================================

Just for reference here are instructions from Linode:
https://www.linode.com/docs/tools-reference/custom-kernels-distros/run-a-custom-compiled-kernel-with-pvgrub

I would expect that you've read Linode documentation and know the basics.

  1. Create new Linode
  2. Create ZeroShell ext3 disk of at least 1GB
  4. Create Installation etx4 disk of at least 2GB
  5. Create Profiles ext3/4 disk of at least 1GB (order of creation is important)
  6. Go into the Rescue Mode
  7. Grab installation files from GitHub:
  
    1. apt-get update
    2. apt-get install --yes git
    3. git clone https://github.com/timothybasanov/zeroshell-linode.git
    4. cd zeroshell-linode.git
    
  5. ./install.sh
  6. Wait for several hours... until it's ready
  7. Create new Configuration Profile:
  
    1. pv-grub-x86-32
    2. /dev/xvda: ZeroShell
    3. /dev/xvdb: Profiles
    4. Root device: /dev/xvda
    5. All Filesystem/Boot Helper knobs enabled
    
  8. Restart into new configuration and wait for ZeroShell to start in lish console
  9. Go to IP Manager and enable DHCP client: ih<Enter>Enabled<Enter>q
  10. Enable Fail-Safe Mode
  11. Your ZeroShell should be accessible by http now


