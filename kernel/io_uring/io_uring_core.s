package neurx.kernel.io_uring

use std.slices

struct io_uring_sqe {
    int opcode
    int fd
    int offset
    int length
    int flags
}

struct io_uring_cqe {
    int result
    int flags
    int user_data
}

struct io_uring {
    io_uring_sqe[] sq
    io_uring_cqe[] cq
    int sq_tail
    int cq_head
}

func create_io_uring(int queue_depth) io_uring {
    uring := io_uring {
        sq: io_uring_sqe[](),
        cq: io_uring_cqe[](),
        sq_tail: 0,
        cq_head: 0
    }
    uring
}

func io_uring_prep_read(io_uring uring, int fd, int offset, int len) io_uring {
    sqe := io_uring_sqe {
        opcode: 0,
        fd: fd,
        offset: offset,
        length: len,
        flags: 0
    }
    uring.sq = append(uring.sq, sqe)
    uring.sq_tail = uring.sq_tail + 1
    uring
}

func io_uring_prep_write(io_uring uring, int fd, int offset, int len) io_uring {
    sqe := io_uring_sqe {
        opcode: 1,
        fd: fd,
        offset: offset,
        length: len,
        flags: 0
    }
    uring.sq = append(uring.sq, sqe)
    uring.sq_tail = uring.sq_tail + 1
    uring
}

func io_uring_submit(io_uring uring) int {
    uring.sq_tail
}

func io_uring_wait_cqe(io_uring uring) io_uring_cqe {
    cqe := io_uring_cqe {
        result: -1,
        flags: 0,
        user_data: 0
    }
    cqe
}
