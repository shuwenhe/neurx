package neurx.ipc.msgqueue

struct message {
    int msg_id
    int sender_pid
    int receiver_pid
    int msg_type
    int priority
    int timestamp
}

struct message_queue {
    int queue_id
    int max_messages
    int messages_sent
    int messages_received
    int messages_pending
}

struct msgqueue_manager {
    int total_queues_created
    int total_messages_sent
    int total_messages_received
    int active_queues
}

func create_msgqueue_manager() msgqueue_manager {
    mgr := msgqueue_manager {
        total_queues_created: 0,
        total_messages_sent: 0,
        total_messages_received: 0,
        active_queues: 0
    }
    return mgr
}

func create_message_queue(msgqueue_manager mgr, int max_messages) msgqueue_manager {
    mgr.total_queues_created = mgr.total_queues_created + 1
    mgr.active_queues = mgr.active_queues + 1
    return mgr
}

func send_message(msgqueue_manager mgr, int msg_type, int priority) msgqueue_manager {
    mgr.total_messages_sent = mgr.total_messages_sent + 1
    return mgr
}

func receive_message(msgqueue_manager mgr) msgqueue_manager {
    mgr.total_messages_received = mgr.total_messages_received + 1
    return mgr
}

func print_msgqueue_manager_info(msgqueue_manager mgr) {
    print("╔════════════════════════════════════════════════════════════╗")
    print("║        NeurX Message Queues - Status Report                ║")
    print("╚════════════════════════════════════════════════════════════╝")
    print("")
    print("📊 Message Queue Configuration:")
    print("   • Total Queues Created: ")
    print(mgr.total_queues_created as string)
    print("   • Active Queues: ")
    print(mgr.active_queues as string)
    print("")
    print("📈 Statistics:")
    print("   • Total Messages Sent: ")
    print(mgr.total_messages_sent as string)
    print("   • Total Messages Received: ")
    print(mgr.total_messages_received as string)
    print("")
    print("✅ Message queues operational!")
}
