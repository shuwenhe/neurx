package neurx.kernel.ipc

func msgqueue_get(int key) int {
    if key > 0 {
        key
    } else {
        -1
    }
}

func msgqueue_create(int key, int flags) int {
    key
}

func msgqueue_send(int msqid, int msgtype, int msglen) int {
    msglen
}

func msgqueue_receive(int msqid, int msgtype) int {
    0
}

func msgqueue_delete(int msqid) int {
    0
}

func msgqueue_stat(int msqid) int {
    1
}

func semget(int key, int nsems, int flags) int {
    if nsems > 0 {
        key
    } else {
        -1
    }
}

func semop(int semid, int nsops) int {
    nsops
}

func semctl(int semid, int semnum, int cmd) int {
    0
}

func shmget(int key, int size, int flags) int {
    if size > 0 {
        key
    } else {
        -1
    }
}

func shmat(int shmid, int shmaddr) int {
    1048576 + shmid
}

func shmdt(int shmaddr) int {
    0
}

func shmctl(int shmid, int cmd) int {
    1
}

func pipe_create() int {
    1
}

func pipe_read(int fd, int addr, int count) int {
    count
}

func pipe_write(int fd, int addr, int count) int {
    count
}

func pipe_close(int fd) int {
    0
}

func socket_create(int domain, int type) int {
    1
}

func socket_connect(int sockfd, int addr) int {
    0
}

func socket_send(int sockfd, int addr, int len) int {
    len
}

func socket_receive(int sockfd, int addr) int {
    0
}

func socket_close(int sockfd) int {
    0
}

func ipc_system_init() int {
    1
}

func ipc_system_shutdown() int {
    0
}

func main() int {
    mq := msgqueue_create(1, 0)
    sem := semget(2, 1, 0)
    shm := shmget(3, 4096, 0)
    status := ipc_system_init()
    status
}

func _start() int {
    main()
}
