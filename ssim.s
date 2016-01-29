#defines

.equiv port, 10631  #port to listen

.equiv fd_socket, %ebp #FD

#socket interface
.equiv SYS_SOCKETCALL, 102
.equiv SYS_SOCKET, 1
.equiv SYS_BIND, 2
.equiv SYS_LISTEN, 4
.equiv SYS_SETSOCKOPT, 105
.equiv SYS_CONNECT, 3
.equiv SOCK_STREAM, 1
.equiv SOL_SOCKET, 1
.equiv SO_REUSEADDR, 2
.equiv AF_INET, 2

#system calls
.equiv SYS_exit, 1
.equiv SYS_read, 3
.equiv SYS_write, 4
.equiv SYS_close, 6

.data

df: .ascii "<html><head><body>Hello!</body></head></html>" #default file to serv
.equ dfLen, . - df

socket_args:
      .long AF_INET
      .int SOCK_STREAM
      .int 0 
      
setsockopt_args:
      .long 0
      .int  SOL_SOCKET
      .int  SO_REUSEADDR
      .int  1
      .int  4 

bind_args:
     .long 0
     .short AF_INET
     .byte port >> 8, port & 0xff
     .int 0
     .int 16 #socket address size
          
listen_args:
     .long 0
     .int 5 #max
       
.text

.weak _start #compile without libs

_start:
  .globl main

main:

  #open socket   
  mov $socket_args,%ecx      #pointer to syscall function args
  mov $SYS_SOCKET,%ebx       #function
  mov $SYS_SOCKETCALL,%eax   #call sys_socket
  int $0x80                  #eax contains FD  
  cmp $0, %eax               #if something wrong
  jl exit
  mov %eax,fd_socket         #save file (socket) descriptor for later 
 
  #reuse address (ie multicast ie reuse port immediately after closing it)
  mov fd_socket,(setsockopt_args)   
  mov $setsockopt_args, %ecx  
  mov $SYS_SETSOCKOPT,%ebx
  mov $SYS_SOCKETCALL,%eax
  int $0x80
  cmp $0, %eax
  jl exit

  #bind to socket
  mov fd_socket, (bind_args)
  mov $bind_args,%ecx
  mov $SYS_BIND,%ebx
  mov $SYS_SOCKETCALL,%eax
  int $0x80
  cmp $0, %eax
  jl exit
 
  #listen
  mov fd_socket,(listen_args)
  mov $listen_args,%ecx
  mov $SYS_LISTEN,%ebx
  mov $SYS_SOCKETCALL,%eax
  int $0x80
  cmp $0, %eax
  jl exit
  
  
  
  #write df 






  jmp ok
ok:
  mov $0,%eax
  jmp exit

 
exit:
  mov %eax,%ebx		# exitcode
  neg %ebx
  mov $SYS_exit,%eax 
  int $0x80

