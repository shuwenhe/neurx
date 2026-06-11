package neurx.test_autograd

use neurx.ad.autodiff_minimal.{grad_graph, new_graph, add_leaf, add_node, sub_node, mul_node, div_node, mean_node, backward, last_node_id, node_data, node_grad}

func main() int {
    grad_graph graph0 = new_graph()
    grad_graph graph1 = add_leaf(graph0, [2.0, 3.0], [2], true)
    grad_graph graph2 = add_leaf(graph1, [4.0, 5.0], [2], true)
    grad_graph graph3 = add_leaf(graph2, [1.0, 2.0], [2], true)
    grad_graph graph4 = mul_node(graph3, 0, 1)
    grad_graph graph5 = sub_node(graph4, 4, 2)
    grad_graph graph6 = div_node(graph5, 5, 1)
    grad_graph graph7 = add_node(graph6, 6, 3)
    grad_graph graph8 = mean_node(graph7, 7)
    grad_graph graph9 = backward(graph8, last_node_id(graph8))

    println("mul = ", node_data(graph8, 4))
    println("sub = ", node_data(graph8, 5))
    println("div = ", node_data(graph8, 6))
    println("mix = ", node_data(graph8, 7))
    println("loss = ", node_data(graph8, 8))
    println("grad_a = ", node_grad(graph9, 0))
    println("grad_b = ", node_grad(graph9, 1))
    println("grad_c = ", node_grad(graph9, 2))
    0
}
