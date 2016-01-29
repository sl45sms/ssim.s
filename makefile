all: ssim.s
     gcc -m32 -nostdlib ssims.s -o ssims.o
     objcopy -S -R .note.gnu.build-id ssims.o ssims

clean :
      rm ssims.o ssims
