#defines

.equiv port, 10631  #port to listen

.equiv bufsiz, 4096    # enough for an HTTP GET request TODO check for pottencial buf overflow?

.equiv path, buf+5


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
.equiv PF_INET, 2
.equiv WNOHANG, 1                /*waitpid should return immediately*/
.equiv ECHILD, 10 

#system calls
.equiv SYS_exit, 1
.equiv SYS_fork, 2
.equiv SYS_read, 3
.equiv SYS_write, 4
.equiv SYS_close, 6
.equiv SYS_waitpid, 7
.equiv SYS_alarm, 27

/**********************************************************************/
.data


index.html: 
     .ascii "HTTP/1.0 200\r\n\r\n<html><head><body>Hello!</body></head></html>" #default file to serv
.equ index.htmlLen, . - index.html

hi.html:
    .ascii "HTTP/1.0 200\r\n\r\n<html><head><body>Hi!</body></head></html>" #default file to serv
.equ hiLen, . - hi.html

#TODO 403 500 etc...

socket_args:
	.int PF_INET                                              /*IPV4*/
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

bufp:   .int 0
buf:    .fill bufsiz, 1, 0

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

#accept sys_accept(int fd, struct sockaddr *upeer_sockaddr, int *upeer_addrlen) 
accept_loop:
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

#
reap_zombies:
	xor %edx, %edx
	cmpl $0, (available_connections)
	jz noconnections
	mov $WNOHANG, %edx
noconnections:
	mov $0,%ecx
	mov $0,%ebx
	mov $SYS_waitpid,%eax
	int $0x80  

	cmp $0, %eax
	jz nozombies                 # WNOHANG not have to wait and no zombies ready for reaping
	jl complain                  # TODO error report
	incl (available_connections) # We reaped a zombie.
	jmp reap_zombies
        
complain:
	cmp $-ECHILD, %eax
	je nozombies   # apocalipse not now
	nop            #TODO complain waitpid
nozombies:
	jmp fork
	nop

#
fork:
	mov $SYS_fork,%eax
	int $0x80   
	cmp $0, %eax
	jg closefork
	jz continuefork 
complainfork:       
	nop                                     /* TODO complain parent have an error */
closefork:
	mov (clientsock),%ebx
	mov $SYS_close,%eax
	int $0x80  
	decl (available_connections)
	jmp accept_loop
continuefork:
	mov (clientsock), fd_socket

setalarm:
	mov $SYS_alarm, %eax                  /* cloce child after 32 sec */
	mov $32,%ebx                          /* if not respont */ 
	int $0x80
	/**************************************/
	/* TODO read client and select "file" */
	/**************************************/

readreq:
	movl $0, (bufp)
keepread:	
	mov (bufp), %eax
	mov $bufsiz-1, %edx
	sub %eax, %edx                    /* calculate remaining space */
        add $buf, %eax
read:       
	mov %edx,%edx
	mov %eax,%ecx
	mov fd_socket,%ebx
	mov $SYS_read, %eax
	int $0x80
	cmp $0, %eax
	jnl noreaderr
readerr:                 
	mov fd_socket,%ebx
	mov $SYS_close,%eax
	int $0x80
        nop                        #TODO report error
	jmp accept_loop

noreaderr:
        je donereading             #eof
	add (bufp), %eax 
	mov %eax, (bufp)
	mov $('\r | '\n << 8 | '\r << 16 | '\n << 24), %eax  #check crlf
        mov $buf, %esi
        mov (bufp), %ecx
        sub $3, %ecx
        jle keepread
allign:
	cmp (%esi), %eax
	je donereading
	inc %esi
	loop allign 
	jmp keepread

donereading:




	#scan path
	cmp $5, (bufp)
	jl badreq               #path too short     

        
        #print headers to stdout
	mov $SYS_write, %eax                     /* use the write syscall*/
	mov $1, %ebx                             /* write to stdout */
	mov $buf, %ecx
	mov $bufsiz, %edx
	int $0x80


 	xor %eax, %eax
	mov $0x20, %al          #look for space 
        mov $buf+5, %edi        #ignore GET
	sub %ecx, %ecx
	not %ecx 
        cld                     #look forward
        repne scasb
        test %ecx, %ecx         #test if %eax is 0       
        jz badreq
#        movb $0, -1(%edi)       # NUL-terminate the path.
#        movb $0x10, -1(%edi)
        not %ecx
	dec %ecx                # %ecx contains the length 
         

#print path to stdout
        mov $SYS_write, %eax                     /* use the write syscall*/
        mov $1, %ebx                             /* write to stdout */
        mov %ecx, %edx                           /* length */
        mov $path, %ecx                          /* path string */
        int $0x80


resetalarm:
	mov $SYS_alarm, %eax                  /*reset alarm*/
	mov $0,%ebx
	int $0x80
 
	jmp write
	nop

write:  
	mov $SYS_write, %eax                     /* use the write syscall*/
	mov fd_socket, %ebx                        /* write to fd_socket */
	mov $index.html, %ecx          
	mov $index.htmlLen, %edx       
	int $0x80
	jmp ok
    
ok:     
        mov $SYS_close, %eax
        mov fd_socket, %ebx
        int $0x80
	mov $0,%eax
	jmp exit

badreq:
        mov $SYS_close, %eax
        mov fd_socket, %ebx
        int $0x80
        mov $1,%eax                           /*TODO send 404 error*/

exit:
	mov %eax,%ebx		                           /* exitcode */
	neg %ebx
	mov $SYS_exit,%eax 
	int $0x80

.end
