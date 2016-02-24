# ssim.s
========================================================================
###Simple Secure In Memory Server

#####Compile manualy
gcc -m32 -nostdlib ssim.s -o ssims.o
objcopy -S -R .note.gnu.build-id ssims.o ssims

#####tips

######dissasembly

objdump -xd ./ssims


###### informations
objdump -s -j .rodata ./ssims   or  readelf -x .rodata ./ssims

readelf -a ./ssims

size -x ./ssims

readelf --symbols ./ssims.o    or   nm ./ssims.o


######debug
strace ./ssims

######file2byte
hexdump -v -e '/1 "0x%02X,"' file |sed s'/.$//'
