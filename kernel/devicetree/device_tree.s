package neurx.kernel.devicetree

use std.slices

struct dt_property {
    string prop_name
    string prop_value
    int prop_len
}

struct dt_node {
    string node_name
    dt_property[] properties
    int[] child_node_ids
    int parent_id
}

struct device_tree {
    dt_node[] nodes
    int root_node_id
    string dt_version
}

struct dt_compatible_device {
    int node_id
    string compatible_string
    string driver_name
    int driver_id
}

struct dt_registry {
    dt_compatible_device[] registered_devices
    int registry_id
}

func create_dt_property(string name, string value) dt_property {
    prop := dt_property {
        prop_name: name,
        prop_value: value,
        prop_len: 0
    }
    prop
}

func create_dt_node(string name) dt_node {
    node := dt_node {
        node_name: name,
        properties: dt_property[](),
        child_node_ids: int[](),
        parent_id: 0
    }
    node
}

func dt_node_add_property(dt_node node, dt_property prop) dt_node {
    node.properties = append(node.properties, prop)
    node
}

func dt_node_add_child(dt_node node, int child_id) dt_node {
    node.child_node_ids = append(node.child_node_ids, child_id)
    node
}

func create_device_tree() device_tree {
    tree := device_tree {
        nodes: dt_node[](),
        root_node_id: 0,
        dt_version: "1.0"
    }
    root := create_dt_node("root")
    tree.nodes = append(tree.nodes, root)
    tree
}

func device_tree_add_node(device_tree tree, dt_node node) device_tree {
    tree.nodes = append(tree.nodes, node)
    tree
}

func create_dt_compatible_device(int node_id, string compatible) dt_compatible_device {
    device := dt_compatible_device {
        node_id: node_id,
        compatible_string: compatible,
        driver_name: "",
        driver_id: 0
    }
    device
}

func create_dt_registry() dt_registry {
    registry := dt_registry {
        registered_devices: dt_compatible_device[](),
        registry_id: 0
    }
    registry
}

func dt_registry_register_device(dt_registry registry, dt_compatible_device device) dt_registry {
    registry.registered_devices = append(registry.registered_devices, device)
    registry
}

func device_tree_get_node_count(device_tree tree) int {
    len(tree.nodes)
}

func dt_registry_get_device_count(dt_registry registry) int {
    len(registry.registered_devices)
}
