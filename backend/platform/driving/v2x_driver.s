package neurx.backend.platform.driving

use std.slices
use std.io.println


    cam,
    denm,
    spa,
    vam,
}

struct v2x_message {
    v2x_message_type mtype
    string sender_id
    []float data
    int timestamp_us
}

struct v2x_driver {
    string network_interface
    int broadcast_rate_hz
    bool v2i_enabled
    bool v2v_enabled
    []string peer_ids
}

func new_v2x_driver(string interface) v2x_driver {
    return v2x_driver{
        network_interface: interface,
        broadcast_rate_hz: 10,
        v2i_enabled: false,
        v2v_enabled: true,
        peer_ids: vec[string](),
    }
}

func (v2x_driver* driver) register_peer(string peer_id) {
    driver.peer_ids.push(peer_id)
}

func (driver* driver) send_message(v2x_message msg) bool {    true
}

func (driver* driver) receive_message() option[v2x_message] {
    option::none[v2x_message]()
}

func (driver* driver) get_peer_count() int {    driver.peer_ids.len()
}

func (driver* driver) get_broadcast_rate_hz() int {    driver.broadcast_rate_hz
}

func (driver* driver) is_v2i_enabled() bool {    driver.v2i_enabled
}

func (driver* driver) is_v2v_enabled() bool {    driver.v2v_enabled
}
