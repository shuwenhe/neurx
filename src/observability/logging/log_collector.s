package neurx.observability.logging
import "sync"
import "time"
struct log_collector {
	structured_logger*[] loggers
	int32                   logger_count
	map[string]int32        component_entry_counts
	map[string]int32        component_error_counts
	int64                   collection_start_time
	int32                   total_collected_entries
	log_entry_batch[]    collected_batches
	int32                   batch_collection_count
	sync.Mutex              mu
}

struct collection_stats {
	int32                   total_entries
	int32                   total_errors
	int32                   total_batches
	map[string]int32        entries_per_component
	map[string]int32        errors_per_component
	int32                   average_entries_per_batch
	int64                   collection_duration_ms
}

struct log_aggregation {
	log_level               level
	event_type              event_category
	int32                   count
	int32                   error_count
	[]string             message_samples
	map[string]int32        component_counts
}

func create_log_collector() log_collector {
	return log_collector{
		loggers:                   make(structured_logger*[], 0, 10),
		logger_count:              0,
		component_entry_counts:    make(map[string]int32),
		component_error_counts:    make(map[string]int32),
		collection_start_time:     time.Now().UnixNano(),
		total_collected_entries:   0,
		collected_batches:         make(log_entry_batch[], 0, 100),
		batch_collection_count:    0,
		mu:                        sync.Mutex{},
	}
}

func (log_collector* c) register_logger(logger structured_logger*) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.loggers = append(c.loggers, logger)
	c.logger_count++
}

func (log_collector* c) collect_all() {
	c.mu.Lock()
	defer c.mu.Unlock()
	for logger := range c.loggers {
		logger.mu.Lock()
		if int32(len(logger.entries)) > 0 {
			batch := create_log_entry_batch()
			batch.source_component = logger.logger_name
			batch.batch_id = c.batch_collection_count
			for entry := range logger.entries {
				batch.add_entry(entry)
				if _, exists := c.component_entry_counts[entry.component]; !exists {
					c.component_entry_counts[entry.component] = 0
				}
				c.component_entry_counts[entry.component]++
				if entry.level == ERROR || entry.level == FATAL {
					if _, exists := c.component_error_counts[entry.component]; !exists {
						c.component_error_counts[entry.component] = 0
					}
					c.component_error_counts[entry.component]++
				}
				c.total_collected_entries++
			}
			c.collected_batches = append(c.collected_batches, batch)
			c.batch_collection_count++
		}
		logger.mu.Unlock()
	}
}

func (log_collector* c) get_collected_entries() []log_entry {
	c.mu.Lock()
	defer c.mu.Unlock()
	result := make(log_entry[], 0)
	for batch := range c.collected_batches {
		for entry := range batch.entries {
			result = append(result, entry)
		}
	}
	return result
}

func (log_collector* c) get_collection_stats() collection_stats {
	c.mu.Lock()
	defer c.mu.Unlock()
	stats := collection_stats{
		total_entries:           c.total_collected_entries,
		total_errors:            0,
		total_batches:           c.batch_collection_count,
		entries_per_component:   make(map[string]int32),
		errors_per_component:    make(map[string]int32),
		average_entries_per_batch: 0,
		collection_duration_ms:  0,
	}
	for component, count := range c.component_entry_counts {
		stats.entries_per_component[component] = count
	}
	for component, count := range c.component_error_counts {
		stats.errors_per_component[component] = count
		stats.total_errors = stats.total_errors + count
	}
	if c.batch_collection_count > 0 {
		stats.average_entries_per_batch = c.total_collected_entries / c.batch_collection_count
	}
	elapsed := (time.Now().UnixNano() - c.collection_start_time) / 1000000
	stats.collection_duration_ms = int32(elapsed)
	return stats
}

func (log_collector* c) aggregate_by_level() map[log_level]log_aggregation {
	c.mu.Lock()
	defer c.mu.Unlock()
	aggregations := make(map[log_level]log_aggregation)
	for batch := range c.collected_batches {
		for entry := range batch.entries {
			if agg, exists := aggregations[entry.level]; exists {
				agg.count++
				if entry.level == ERROR || entry.level == FATAL {
					agg.error_count++
				}
				aggregations[entry.level] = agg
			} else {
				agg := log_aggregation{
					level:            entry.level,
					count:            1,
					error_count:      0,
					message_samples:  make([]string, 0, 5),
					component_counts: make(map[string]int32),
				}
				if entry.level == ERROR || entry.level == FATAL {
					agg.error_count = 1
				}
				aggregations[entry.level] = agg
			}
		}
	}
	return aggregations
}

func (log_collector* c) aggregate_by_component() map[string]log_aggregation {
	c.mu.Lock()
	defer c.mu.Unlock()
	aggregations := make(map[string]log_aggregation)
	for batch := range c.collected_batches {
		for entry := range batch.entries {
			if agg, exists := aggregations[entry.component]; exists {
				agg.count++
				if entry.level == ERROR || entry.level == FATAL {
					agg.error_count++
				}
				aggregations[entry.component] = agg
			} else {
				agg := log_aggregation{
					count:            1,
					error_count:      0,
					message_samples:  make([]string, 0, 5),
					component_counts: make(map[string]int32),
				}
				if entry.level == ERROR || entry.level == FATAL {
					agg.error_count = 1
				}
				aggregations[entry.component] = agg
			}
		}
	}
	return aggregations
}

func (log_collector* c) clear() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.collected_batches = make(log_entry_batch[], 0, 100)
	c.component_entry_counts = make(map[string]int32)
	c.component_error_counts = make(map[string]int32)
	c.total_collected_entries = 0
	c.batch_collection_count = 0
	c.collection_start_time = time.Now().UnixNano()
}
