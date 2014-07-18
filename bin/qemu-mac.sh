qemu-system-x86_64 -enable-kvm -M q35 -m 8192 -cpu host -vga none -monitor stdio \
-smp cpus=4,cores=2 -smbios type=2 \
-usb -usbdevice host:046d:c70a -usbdevice host:046d:c70e -usbdevice host:046d:0b02 \
-device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1 \
-device vfio-pci,host=02:00.0,bus=root.1,addr=00.0,multifunction=on,x-vga=on \
-drive file=/media/files/VMs/mac10.9.qcow2,id=disk0 -device ide-hd,bus=ide.0,drive=disk0 \
-drive file=/media/files/Tools/OSX-Mavericks.iso,id=isocd -device ide-cd,bus=ide.1,drive=isocd \

#-drive file=/dev/sda6,id=disk0,format=raw -device ide-hd,bus=ide.0,drive=disk0 \
#-drive file=/dev/sda7,id=disk1,format=raw -device ide-hd,bus=ide.1,drive=disk1 \
#-drive file=/dev/sda8,id=disk2,format=raw -device ide-hd,bus=ide.2,drive=disk2 \

#-device isa-applesmc,osk="asdfbjlk" \
#-kernel ~ttouch/Downloads/hackintosh/chameleon_svn2360_boot \
