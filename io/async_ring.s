package neurx.io.async

struct io_request {
    int request_id
    int operation
    int user_addr
    int kernel_addr
    int length
    int result
    int status
}

struct io_ring {
    int ring_size
    int head
    int tail
    int completed
}

func io_ring_init(int size) io_ring {
    ring := io_ring {
        ring_size = size
        head = 0
        tail = 0
        completed = 0
    }
    ring
}

func (io_ring* ring) io_ring_submit(int request_id) int {
    if ring.tail >= ring.ring_size {
        -1
    } else {
        ring.tail = ring.tail + 1
        ring.tail - 1
    }
}

func (io_ring* ring) io_ring_wait_completion(int timeout) int {
    completed := 0
    i := ring.head
    for i < ring.tail {
        completed = completed + 1
        i = i + 1
    }
    completed
}

func (io_ring* ring) io_ring_capacity() int {
    ring.ring_size - ring.tail + ring.head
}

func (io_ring* ring) io_ring_pending() int {
    ring.tail - ring.head
}

func (io_ring* ring) io_ring_flush() int {
    processed := ring.tail - ring.head
    ring.head = ring.tail
    processed
}
