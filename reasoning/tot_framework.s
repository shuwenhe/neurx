package reasoning

import "sync"
import "time"

enum node_status {
	UNEXPLORED = 0
	EXPLORING = 1
	EVALUATED = 2
	PRUNED = 3
	SELECTED = 4
}

enum traversal_type {
	BREADTH_FIRST = 0
	DEPTH_FIRST = 1
	BEST_FIRST = 2
	BEAM_SEARCH = 3
}

struct tree_node {
	string          id
	string          content
	float32         score
	node_status     status
	int32           depth
	int32           parent_index
	vec[int32]      children_indices
	int64           created_at
	int64           evaluated_at
	vec[string]     metadata
}

struct tot_branch {
	int32           branch_id
	vec[tree_node]  nodes
	float32         best_score
	int32           best_node_index
	int64           branch_created
}

struct tot_framework {
	vec[tree_node]          all_nodes
	vec[tot_branch]         branches

	string                  initial_problem
	int32                   max_depth
	int32                   branching_factor
	int32                   beam_width

	traversal_type          traversal_method

	int32                   current_depth
	float32                 best_solution_score
	string                  best_solution_id

	map[string]float32      node_scores
	map[string]int32        node_depths

	bool                    solution_found
	sync.Mutex              mu
}

func create_tot_framework(
	problem string,
	max_depth int32,
	branching_factor int32,
) tot_framework {
	return tot_framework{
		all_nodes:              make(vec[tree_node], 0, 1000),
		branches:               make(vec[tot_branch], 0, 100),
		initial_problem:        problem,
		max_depth:              max_depth,
		branching_factor:       branching_factor,
		beam_width:             5,
		traversal_method:       BEST_FIRST,
		current_depth:          0,
		best_solution_score:    0.0,
		best_solution_id:       "",
		node_scores:            make(map[string]float32),
		node_depths:            make(map[string]int32),
		solution_found:         false,
		mu:                     sync.Mutex{},
	}
}

func (tot_framework* t) add_root_node(content string) string {
	t.mu.Lock()
	defer t.mu.Unlock()

	node_id := "node_root_" + string(time.Now().UnixNano())

	node := tree_node{
		id:              node_id,
		content:         content,
		score:           0.0,
		status:          UNEXPLORED,
		depth:           0,
		parent_index:    -1,
		children_indices: make(vec[int32], 0, t.branching_factor),
		created_at:      time.Now().UnixNano(),
		metadata:        make(vec[string], 0),
	}

	t.all_nodes = append(t.all_nodes, node)
	t.node_scores[node_id] = 0.0
	t.node_depths[node_id] = 0

	return node_id
}

func (tot_framework* t) expand_node(
	parent_id string,
	child_contents vec[string],
) vec[string] {
	t.mu.Lock()
	defer t.mu.Unlock()

	parent_index := int32(-1)
	for i := int32(0); i < int32(len(t.all_nodes)); i++ {
		if t.all_nodes[i].id == parent_id {
			parent_index = i
			break
		}
	}

	if parent_index < 0 {
		return make(vec[string], 0)
	}

	parent := t.all_nodes[parent_index]

	if parent.depth >= t.max_depth {
		return make(vec[string], 0)
	}

	child_ids := make(vec[string], 0, len(child_contents))

	for content := range child_contents {
		if int32(len(t.all_nodes)) >= 1000 {
			break
		}

		child_id := "node_" + string(time.Now().UnixNano()) + "_" + string(len(child_ids))

		child := tree_node{
			id:               child_id,
			content:          content,
			score:            0.0,
			status:           UNEXPLORED,
			depth:            parent.depth + 1,
			parent_index:     parent_index,
			children_indices: make(vec[int32], 0, t.branching_factor),
			created_at:       time.Now().UnixNano(),
			metadata:         make(vec[string], 0),
		}

		child_index := int32(len(t.all_nodes))
		t.all_nodes = append(t.all_nodes, child)
		t.all_nodes[parent_index].children_indices = append(
			t.all_nodes[parent_index].children_indices,
			child_index,
		)

		child_ids = append(child_ids, child_id)
		t.node_scores[child_id] = 0.0
		t.node_depths[child_id] = parent.depth + 1
	}

	t.all_nodes[parent_index].status = EXPLORING

	return child_ids
}

func (tot_framework* t) update_node_score(
	node_id string,
	score float32,
) bool {
	t.mu.Lock()
	defer t.mu.Unlock()

	for i := int32(0); i < int32(len(t.all_nodes)); i++ {
		if t.all_nodes[i].id == node_id {
			t.all_nodes[i].score = score
			t.all_nodes[i].status = EVALUATED
			t.all_nodes[i].evaluated_at = time.Now().UnixNano()
			t.node_scores[node_id] = score

			if score > t.best_solution_score {
				t.best_solution_score = score
				t.best_solution_id = node_id
			}

			return true
		}
	}

	return false
}

func (tot_framework* t) prune_branch(node_id string) bool {
	t.mu.Lock()
	defer t.mu.Unlock()

	for i := int32(0); i < int32(len(t.all_nodes)); i++ {
		if t.all_nodes[i].id == node_id {
			t.all_nodes[i].status = PRUNED
			return t.prune_descendants(i)
		}
	}

	return false
}

func (tot_framework* t) prune_descendants(parent_index int32) bool {
	if parent_index < 0 || parent_index >= int32(len(t.all_nodes)) {
		return false
	}

	for child_idx := range t.all_nodes[parent_index].children_indices {
		if child_idx < int32(len(t.all_nodes)) {
			t.all_nodes[child_idx].status = PRUNED
			t.prune_descendants(child_idx)
		}
	}

	return true
}

func (tot_framework* t) breadth_first_traversal() vec[string] {
	t.mu.Lock()
	defer t.mu.Unlock()

	traversal := make(vec[string], 0, len(t.all_nodes))

	if int32(len(t.all_nodes)) == 0 {
		return traversal
	}

	queue := make(vec[int32], 0, len(t.all_nodes))
	queue = append(queue, 0)

	for int32(len(queue)) > 0 {
		node_index := queue[0]
		queue = queue[1:]

		if node_index >= int32(len(t.all_nodes)) {
			continue
		}

		node := t.all_nodes[node_index]
		if node.status != PRUNED {
			traversal = append(traversal, node.id)
		}

		for child_idx := range node.children_indices {
			if child_idx < int32(len(t.all_nodes)) {
				queue = append(queue, child_idx)
			}
		}
	}

	return traversal
}

func (tot_framework* t) depth_first_traversal() vec[string] {
	t.mu.Lock()
	defer t.mu.Unlock()

	traversal := make(vec[string], 0, len(t.all_nodes))

	if int32(len(t.all_nodes)) == 0 {
		return traversal
	}

	stack := make(vec[int32], 0, len(t.all_nodes))
	stack = append(stack, 0)

	for int32(len(stack)) > 0 {
		node_index := stack[int32(len(stack))-1]
		stack = stack[:int32(len(stack))-1]

		if node_index >= int32(len(t.all_nodes)) {
			continue
		}

		node := t.all_nodes[node_index]
		if node.status != PRUNED {
			traversal = append(traversal, node.id)
		}

		for i := int32(len(node.children_indices)) - 1; i >= 0; i-- {
			child_idx := node.children_indices[i]
			if child_idx < int32(len(t.all_nodes)) {
				stack = append(stack, child_idx)
			}
		}
	}

	return traversal
}

func (tot_framework* t) best_first_traversal() vec[string] {
	t.mu.Lock()
	defer t.mu.Unlock()

	traversal := make(vec[string], 0, len(t.all_nodes))

	if int32(len(t.all_nodes)) == 0 {
		return traversal
	}

	sorted_nodes := make(vec[int32], 0, len(t.all_nodes))
	for i := int32(0); i < int32(len(t.all_nodes)); i++ {
		sorted_nodes = append(sorted_nodes, i)
	}

	for i := int32(0); i < int32(len(sorted_nodes)); i++ {
		for j := i + 1; j < int32(len(sorted_nodes)); j++ {
			idx_i := sorted_nodes[i]
			idx_j := sorted_nodes[j]
			if t.all_nodes[idx_j].score > t.all_nodes[idx_i].score {
				sorted_nodes[i] = idx_j
				sorted_nodes[j] = idx_i
			}
		}
	}

	for idx := range sorted_nodes {
		if idx < int32(len(t.all_nodes)) {
			if t.all_nodes[idx].status != PRUNED {
				traversal = append(traversal, t.all_nodes[idx].id)
			}
		}
	}

	return traversal
}

func (tot_framework* t) beam_search_traversal(beam_width int32) vec[string] {
	t.mu.Lock()
	defer t.mu.Unlock()

	traversal := make(vec[string], 0, beam_width*t.max_depth)

	if int32(len(t.all_nodes)) == 0 {
		return traversal
	}

	current_level := make(vec[int32], 0, beam_width)
	current_level = append(current_level, 0)

	for depth := int32(0); depth < t.max_depth; depth++ {
		if int32(len(current_level)) == 0 {
			break
		}

		next_level := make(vec[int32], 0, beam_width)

		for node_idx := range current_level {
			if node_idx >= int32(len(t.all_nodes)) {
				continue
			}

			node := t.all_nodes[node_idx]
			traversal = append(traversal, node.id)

			for child_idx := range node.children_indices {
				if child_idx < int32(len(t.all_nodes)) {
					next_level = append(next_level, child_idx)
				}
			}
		}

		if int32(len(next_level)) > beam_width {
			sorted_children := t.sort_by_score(next_level)
			current_level = sorted_children[:beam_width]
		} else {
			current_level = next_level
		}
	}

	return traversal
}

func (tot_framework* t) sort_by_score(indices vec[int32]) vec[int32] {
	sorted := make(vec[int32], 0, len(indices))
	for idx := range indices {
		sorted = append(sorted, idx)
	}

	for i := int32(0); i < int32(len(sorted)); i++ {
		for j := i + 1; j < int32(len(sorted)); j++ {
			idx_i := sorted[i]
			idx_j := sorted[j]
			if t.all_nodes[idx_j].score > t.all_nodes[idx_i].score {
				sorted[i] = idx_j
				sorted[j] = idx_i
			}
		}
	}

	return sorted
}

func (tot_framework* t) get_best_path() vec[string] {
	t.mu.Lock()
	defer t.mu.Unlock()

	path := make(vec[string], 0, t.max_depth)

	if len(t.best_solution_id) == 0 {
		return path
	}

	current_id := t.best_solution_id
	current_index := int32(-1)

	for i := int32(0); i < int32(len(t.all_nodes)); i++ {
		if t.all_nodes[i].id == current_id {
			current_index = i
			break
		}
	}

	for current_index >= 0 {
		if current_index >= int32(len(t.all_nodes)) {
			break
		}

		path = append(path, t.all_nodes[current_index].id)
		current_index = t.all_nodes[current_index].parent_index
	}

	reversed := make(vec[string], 0, len(path))
	for i := int32(len(path)) - 1; i >= 0; i-- {
		reversed = append(reversed, path[i])
	}

	return reversed
}

func (tot_framework* t) get_node_by_id(node_id string) (tree_node, bool) {
	t.mu.Lock()
	defer t.mu.Unlock()

	for node := range t.all_nodes {
		if node.id == node_id {
			return node, true
		}
	}

	return tree_node{}, false
}

func (tot_framework* t) get_children(parent_id string) vec[tree_node] {
	t.mu.Lock()
	defer t.mu.Unlock()

	children := make(vec[tree_node], 0)

	for node := range t.all_nodes {
		if node.id == parent_id {
			for child_idx := range node.children_indices {
				if child_idx < int32(len(t.all_nodes)) {
					children = append(children, t.all_nodes[child_idx])
				}
			}
			break
		}
	}

	return children
}

func (tot_framework* t) get_solution() (string, float32, bool) {
	t.mu.Lock()
	defer t.mu.Unlock()

	if len(t.best_solution_id) == 0 {
		return "", 0.0, false
	}

	for node := range t.all_nodes {
		if node.id == t.best_solution_id {
			return node.content, node.score, true
		}
	}

	return "", 0.0, false
}

func (tot_framework* t) get_tree_stats() map[string]int32 {
	t.mu.Lock()
	defer t.mu.Unlock()

	stats := make(map[string]int32)
	stats["total_nodes"] = int32(len(t.all_nodes))

	unexplored := int32(0)
	exploring := int32(0)
	evaluated := int32(0)
	pruned := int32(0)

	for node := range t.all_nodes {
		if node.status == UNEXPLORED {
			unexplored++
		} else if node.status == EXPLORING {
			exploring++
		} else if node.status == EVALUATED {
			evaluated++
		} else if node.status == PRUNED {
			pruned++
		}
	}

	stats["unexplored"] = unexplored
	stats["exploring"] = exploring
	stats["evaluated"] = evaluated
	stats["pruned"] = pruned
	stats["current_depth"] = t.current_depth

	return stats
}

func (tot_framework* t) reset() {
	t.mu.Lock()
	defer t.mu.Unlock()

	t.all_nodes = make(vec[tree_node], 0, 1000)
	t.branches = make(vec[tot_branch], 0, 100)
	t.current_depth = 0
	t.best_solution_score = 0.0
	t.best_solution_id = ""
	t.node_scores = make(map[string]float32)
	t.node_depths = make(map[string]int32)
	t.solution_found = false
}
