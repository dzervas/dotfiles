export QEMU_AUDIO_DRV=alsa
#export QEMU_AUDIO_TIMER_PERIOD=0
#export QEMU_AUDIO_DAC_FIXED_FREQ=48000
#export QEMU_AUDIO_ADC_FIXED_FREQ=48000
#export QEMU_ALSA_DAC_BUFFER_SIZE=16384

#taskset -c 2,3,4,5,6,7 qemu-system-x86_64 -enable-kvm -M q35 -m 10240 -cpu SandyBridge,hv-time \
qemu-system-x86_64 -enable-kvm -M q35 -m 10240 -cpu SandyBridge,hv-time \
-vga none -monitor stdio -smp cpus=6,cores=6 -nographic \
-usb -usbdevice host:046d:c70a -usbdevice host:046d:c70e -usbdevice host:046d:0b02 \
-device ioh3420,bus=pcie.0,addr=1c.0,multifunction=on,port=1,chassis=1,id=root.1 \
-device vfio-pci,host=02:00.0,bus=root.1,addr=00.0,multifunction=on,x-vga=on \
-drive file=/dev/sda9,id=disk1,format=raw -device ide-hd,bus=ide.1,drive=disk1 \
-drive file=/media/files/VMs/windows7.qcow2,id=disk0 -device ide-hd,bus=ide.0,drive=disk0 \

#-drive file=/media/files/Tools/OS\ X\ Mavericks\ Install\ DVD.img,id=isocd -device ide-cd,bus=ide.2,drive=isocd \

#-drive file=/dev/sda6,id=disk0,format=raw -device ide-hd,bus=ide.0,drive=disk0 \
#-drive file=/dev/sda7,id=disk1,format=raw -device ide-hd,bus=ide.1,drive=disk1 \
#-drive file=/dev/sda8,id=disk2,format=raw -device ide-hd,bus=ide.2,drive=disk2 \
#-drive file=/dev/sda9,id=disk3,format=raw -device ide-hd,bus=ide.3,drive=disk3 \

#-device intel-hda,bus=pcie.0,addr=0x4,id=sound0 \
#-device hda-micro,id=sound0-codec0,bus=sound0.0,cad=0 \
