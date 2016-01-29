all: ssims.o
     objcopy -S -R .note.gnu.build-id ssims.o ssims

ssims.o: ssim.s     
     gcc -m32 -nostdlib ssims.s -o ssims.o

clean:
      rm ssims.o ssims
