#defines

.equiv port, 10631  #port to listen

.equiv fd_socket, %ebp #FD file descriptor

.equiv sockaddr_in_size, 16

#socket interface
.equiv SYS_socketcall, 102

.equiv SYS_SOCKET, 1   
.equiv SYS_BIND, 2
.equiv SYS_LISTEN, 4
.equiv SYS_ACCEPT, 5
.equiv SYS_SETSOCKOPT, 14
.equiv SYS_CONNECT, 3
.equiv SOCK_STREAM, 1                 /* stream (connection) socket	*/
.equiv SOL_SOCKET, 1
.equiv SO_REUSEADDR, 2
.equiv AF_INET, 2                    /* Internet IP (V4) Protocol 	*/
.equiv WNOHANG, 1                /*waitpid should return immediately*/
.equiv ECHILD, 10 

#system calls
.equiv SYS_exit, 1
.equiv SYS_fork, 2
.equiv SYS_read, 3
.equiv SYS_write, 4
.equiv SYS_close, 6
.equiv SYS_waitpid, 7

/**********************************************************************/
.data

df: 
	.ascii "HTTP/1.0 200\r\n\r\n<html><head><body>Hello!</body></head></html>" #default file to serv
.equ dfLen, . - df

socket_args:
	.int AF_INET                                              /*IPV4*/
	.int SOCK_STREAM        /*two-way, connection-based byte streams*/
	.int 0 

optval:
	.int 1    
setsockopt_args:
	.int  0
	.int  SOL_SOCKET
	.int  SO_REUSEADDR
	.int optval                                /* pointer to optval */
	.int  4                                     /* sizeof socklen_t */

addr:   
	.short AF_INET                                             /*IPV4*/
	.byte port>>8,port & 0xff
	.int 0                                    /* INADDR_ANY: 0.0.0.0 */
bind_args:
	.int 0
	.int addr
	.int sockaddr_in_size                     /* socket address size */
          
listen_args:
	.int 0
	.int 5 #max
       
accept_args:
	.int 0
	.int sockaddr
	.int sockaddr_size     

available_connections:
	.int 2048

#error's
err_accept:
	.ascii "Error 1: at accept";
#... TODO other errors


/******************************************************************************/       
.bss
sockaddr:
	.fill sockaddr_in_size, 1,0

sockaddr_size:
	.int 0

clientsock:
	.int 0

/******************************************************************************/
.text

.weak _start #compile without libs

_start:
	.globl main
  
main:

	#open socket sys_socket(int family, int type, int protocol)  
	mov $socket_args,%ecx      #pointer to syscall function args
	mov $SYS_SOCKET,%ebx       #function
	mov $SYS_socketcall,%eax   #call sys_socket
	int $0x80                  #eax contains FD  
	cmp $0, %eax               #if something wrong
	jl exit
 
	mov %eax,fd_socket         #save file (socket) descriptor for later 
 
	#reuse address (ie multicast for UDP ie for TCP reuse port immediately after closing it)
	#sys_setsockopt(int fd, int level, int optname, char *optval, int optlen)
	mov fd_socket,(setsockopt_args)
	mov $setsockopt_args, %ecx
	mov $SYS_SETSOCKOPT,%ebx
	mov $SYS_socketcall,%eax
	int $0x80
	cmp $0, %eax
	jl exit

	#bind to socket  sys_bind(int fd, struct sockaddr *umyaddr, int addrlen)
	mov fd_socket, (bind_args)
	mov $bind_args,%ecx
	mov $SYS_BIND,%ebx
	mov $SYS_socketcall,%eax
	int $0x80
	cmp $0, %eax
	jl exit
 
	#listen sys_listen(int fd, int backlog)
	mov fd_socket,(listen_args)
	mov $listen_args,%ecx
	mov $SYS_LISTEN,%ebx
	mov $SYS_socketcall,%eax
	int $0x80
	cmp $0, %eax
	jl exit

#accept  
accept_loop:
	accept sys_accept(int fd, struct sockaddr *upeer_sockaddr, int *upeer_addrlen)
	mov fd_socket, (accept_args)
	mov $accept_args,%ecx
	mov $SYS_ACCEPT,%ebx
	mov $SYS_socketcall,%eax
	int $0x80
	mov %eax, (clientsock)
	cmp $0, %eax  
	jnl reap_zombies
	nop # TODO on failure, complain.
	jmp accept_loop
reap_zombies: 
zombies:
	xor %edx, %edx
	cmpl $0, (available_connections)
	jz noconnections
        
	mov $WNOHANG, %edx
	mov $0,%ecx
	mov $0,%ebx
	mov $SYS_waitpid,%eax
	int $0x80  

	cmp $0, %eax
	jz nozombies                 # WNOHANG not have to wait and no zombies ready for reaping
	jl complain                  # TODO error report
	incl (available_connections) # We reaped a zombie.
	jmp zombies
        
noconnections:
	cmp $-ECHILD, %eax
	je nozombies   # apocalipse not now
complain:
	nop            #TODO complain waitpid
nozombies:
	jmp fork
	nop
fork:
	mov $SYS_fork,%eax
	int $0x80   
	cmp $0, %eax
	jg closefork
	jz continuefork 
complainfork:       
	nop #TODO complain
closefork:
	mov (clientsock),%ebx
	mov $SYS_close,%eax
	int $0x80  
	decl (available_connections)
	jmp accept_loop
continuefork:
	jmp write
	nop
write:  
	movl $SYS_write, %eax                     /* use the write syscall*/
	movl clientsock, %ebx                 /*TODO write to clientsocket*/
	movl $df, %ecx          
	movl $dfLen, %edx       
	int $0x80       
	jmp ok
    
ok:
	mov $0,%eax
	jmp exit

exit:
	mov %eax,%ebx		                           /* exitcode */
	neg %ebx
	mov $SYS_exit,%eax 
	int $0x80

.end
