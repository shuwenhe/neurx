package plugins

import "sync"
import "time"


	MSG_REQUEST = 0
	MSG_RESPONSE = 1
	MSG_EVENT = 2
	MSG_ERROR = 3
	MSG_PING = 4
	MSG_PONG = 5
}


	PRIORITY_LOW = 0
	PRIORITY_NORMAL = 1
	PRIORITY_HIGH = 2
	PRIORITY_CRITICAL = 3
}

struct plugin_message {
	string                  message_id
	message_type            msg_type
	message_priority        priority

	string                  sender_plugin_id
	string                  receiver_plugin_id

	string                  message_subject
	string                  message_body

	map[string]interface{}  message_payload

	int64                   sent_time
	int64                   received_time

	bool                    requires_response
	string                  response_to_message_id

	int32                   retry_count
	int32                   max_retries

	int64                   expiry_time
}

struct message_handler {
	string                  handler_id
	string                  handler_name

	message_type[]       handled_message_types
	int32                   handler_type_count

	int32                   messages_processed
	int32                   messages_failed

	int64                   created_at
}

struct plugin_communication_channel {
	map[string]plugin_message[]]  message_queue

	message_handler[]            handlers
	int32                           handler_count

	int32                           total_messages_sent
	int32                           total_messages_received
	int32                           total_messages_failed

	int32                           max_queue_size

	sync.Mutex                      mu
}

struct message_router {
	plugin_communication_channel    channel

	map[string]string]              plugin_address_map
	map[string]string[]]         plugin_subscription_map

	int32                           total_routes
	int32                           total_subscriptions

	sync.Mutex                      mu
}

struct message_response {
	string                  response_id
	string                  request_message_id

	int32                   status_code
	string                  status_message

	map[string]interface{}  response_data

	int64                   response_time
}

func create_plugin_message(msg_id string, msg_type message_type, sender string, receiver string) plugin_message {
	return plugin_message{
		message_id:            msg_id,
		msg_type:              msg_type,
		priority:              PRIORITY_NORMAL,
		sender_plugin_id:      sender,
		receiver_plugin_id:    receiver,
		message_subject:       "",
		message_body:          "",
		message_payload:       make(map[string]interface{}),
		sent_time:             time.Now().UnixNano(),
		received_time:         0,
		requires_response:     false,
		response_to_message_id: "",
		retry_count:           0,
		max_retries:           3,
		expiry_time:           time.Now().UnixNano() + 60000000000,
	}
}

func create_plugin_communication_channel() plugin_communication_channel {
	return plugin_communication_channel{
		message_queue:           make(map[string]plugin_message[]),
		handlers:                make(message_handler[], 0),
		handler_count:           0,
		total_messages_sent:     0,
		total_messages_received: 0,
		total_messages_failed:   0,
		max_queue_size:          10000,
		mu:                      sync.Mutex{},
	}
}

func create_message_handler(handler_id string, name string) message_handler {
	return message_handler{
		handler_id:              handler_id,
		handler_name:            name,
		handled_message_types:   make(message_type[], 0),
		handler_type_count:      0,
		messages_processed:      0,
		messages_failed:         0,
		created_at:              time.Now().UnixNano(),
	}
}

func create_message_router() message_router {
	return message_router{
		channel:                 create_plugin_communication_channel(),
		plugin_address_map:      make(map[string]string),
		plugin_subscription_map: make(map[string]string[]),
		total_routes:            0,
		total_subscriptions:     0,
		mu:                      sync.Mutex{},
	}
}

func (plugin_communication_channel* c) send_message(message plugin_message) bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	receiver_id := message.receiver_plugin_id

	queue, exists := c.message_queue[receiver_id]
	if !exists {
		queue = make(plugin_message[], 0)
	}

	if int32(len(queue)) >= c.max_queue_size {
		return false
	}

	queue = append(queue, message)
	c.message_queue[receiver_id] = queue
	c.total_messages_sent++

	return true
}

func (plugin_communication_channel* c) receive_message(plugin_id string) (plugin_message, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	queue, exists := c.message_queue[plugin_id]
	if !exists || int32(len(queue)) == 0 {
		return plugin_message{}, false
	}

	message := queue[0]
	message.received_time = time.Now().UnixNano()

	new_queue := make(plugin_message[], 0)
	for i := int32(1); i < int32(len(queue)); i++ {
		new_queue = append(new_queue, queue[i])
	}
	c.message_queue[plugin_id] = new_queue

	c.total_messages_received++

	return message, true
}

func (plugin_communication_channel* c) get_pending_message_count(plugin_id string) int32 {
	c.mu.Lock()
	defer c.mu.Unlock()

	queue, exists := c.message_queue[plugin_id]
	if exists {
		return int32(len(queue))
	}
	return 0
}

func (plugin_communication_channel* c) register_handler(handler message_handler) bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.handlers = append(c.handlers, handler)
	c.handler_count++

	return true
}

func (plugin_communication_channel* c) handle_message(plugin_id string) int32 {
	c.mu.Lock()
	defer c.mu.Unlock()

	queue, exists := c.message_queue[plugin_id]
	if !exists || int32(len(queue)) == 0 {
		return 0
	}

	processed := int32(0)

	for i := int32(0); i < int32(len(queue)); i++ {
		message := queue[i]

		for handler := range c.handlers {
			for msg_type := range handler.handled_message_types {
				if msg_type == message.msg_type {
					processed++
				}
			}
		}
	}

	return processed
}

func (plugin_communication_channel* c) get_channel_stats() map[string]interface{} {
	c.mu.Lock()
	defer c.mu.Unlock()

	stats := make(map[string]interface{})
	stats["total_messages_sent"] = c.total_messages_sent
	stats["total_messages_received"] = c.total_messages_received
	stats["total_messages_failed"] = c.total_messages_failed
	stats["total_handlers"] = c.handler_count
	stats["queue_size"] = int32(len(c.message_queue))

	return stats
}

func (message_router* r) register_plugin(plugin_id string, address string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	_, exists := r.plugin_address_map[plugin_id]
	if exists {
		return false
	}

	r.plugin_address_map[plugin_id] = address
	r.total_routes++

	return true
}

func (message_router* r) subscribe_to_event(plugin_id string, event_topic string) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	subscribers, exists := r.plugin_subscription_map[event_topic]
	if !exists {
		subscribers = make(string[], 0)
	}

	for sub := range subscribers {
		if sub == plugin_id {
			return false
		}
	}

	subscribers = append(subscribers, plugin_id)
	r.plugin_subscription_map[event_topic] = subscribers
	r.total_subscriptions++

	return true
}

func (message_router* r) publish_event(event_topic string, message plugin_message) int32 {
	r.mu.Lock()
	defer r.mu.Unlock()

	subscribers, exists := r.plugin_subscription_map[event_topic]
	if !exists {
		return 0
	}

	published := int32(0)

	for receiver := range subscribers {
		message.receiver_plugin_id = receiver
		message.msg_type = MSG_EVENT
		r.channel.send_message(message)
		published++
	}

	return published
}

func (message_router* r) route_message(message plugin_message) bool {
	r.mu.Lock()
	defer r.mu.Unlock()

	_, exists := r.plugin_address_map[message.receiver_plugin_id]
	if !exists {
		return false
	}

	return r.channel.send_message(message)
}

func (plugin_message* m) set_payload(key string, value interface{}) {
	m.message_payload[key] = value
}

func (plugin_message* m) get_payload(key string) (interface{}, bool) {
	value, exists := m.message_payload[key]
	return value, exists
}

func (plugin_message* m) is_expired() bool {
	return time.Now().UnixNano() > m.expiry_time
}

func (plugin_message* m) get_latency_ms() int64 {
	if m.received_time == 0 {
		return 0
	}
	return (m.received_time - m.sent_time) / 1000000
}
