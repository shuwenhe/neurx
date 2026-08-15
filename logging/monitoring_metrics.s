package logging

import "sync"
import "time"

enum metric_type {
	COUNTER = 0
	GAUGE = 1
	HISTOGRAM = 2
	SUMMARY = 3
}

struct metric_point {
	string              metric_name
	metric_type         metric_category
	
	float32             value
	int64               timestamp
	
	map[string]string   labels
	
	int32               observation_count
	float32             min_value
	float32             max_value
	float32             sum_value
}

struct metric_series {
	string              metric_name
	metric_type         metric_category
	
	vec[metric_point]   points
	int32               point_count
	
	map[string]string   common_labels
	
	int32               retention_hours
	int64               created_at
}

struct metrics_registry {
	map[string]metric_series] metrics
	int32                   metric_count
	
	vec[string]             component_metrics
	map[string]int32        component_metric_counts
	
	int64                   last_collection_time
	int32                   collection_interval_ms
	
	sync.Mutex              mu
}

func create_metric_series(name string, category metric_type) metric_series {
	return metric_series{
		metric_name:     name,
		metric_category: category,
		points:          make(vec[metric_point], 0, 1000),
		point_count:     0,
		common_labels:   make(map[string]string),
		retention_hours: 24,
		created_at:      time.Now().UnixNano(),
	}
}

func create_metrics_registry() metrics_registry {
	return metrics_registry{
		metrics:                   make(map[string]metric_series),
		metric_count:              0,
		component_metrics:         make(vec[string], 0, 50),
		component_metric_counts:   make(map[string]int32),
		last_collection_time:      time.Now().UnixNano(),
		collection_interval_ms:    5000,
		mu:                        sync.Mutex{},
	}
}

func (metrics_registry* r) register_metric(series metric_series) {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	r.metrics[series.metric_name] = series
	r.metric_count++
}

func (metrics_registry* r) record_metric(metric_name string, value float32) {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	if series, exists := r.metrics[metric_name]; exists {
		point := metric_point{
			metric_name:       metric_name,
			metric_category:   series.metric_category,
			value:             value,
			timestamp:         time.Now().UnixNano(),
			labels:            make(map[string]string),
			observation_count: 1,
			min_value:         value,
			max_value:         value,
			sum_value:         value,
		}
		
		series.points = append(series.points, point)
		series.point_count++
		r.metrics[metric_name] = series
	}
}

func (metrics_registry* r) record_observation(metric_name string, value float32, labels map[string]string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	if series, exists := r.metrics[metric_name]; exists {
		point := metric_point{
			metric_name:       metric_name,
			metric_category:   series.metric_category,
			value:             value,
			timestamp:         time.Now().UnixNano(),
			labels:            labels,
			observation_count: 1,
			min_value:         value,
			max_value:         value,
			sum_value:         value,
		}
		
		series.points = append(series.points, point)
		series.point_count++
		r.metrics[metric_name] = series
	}
}

func (metrics_registry* r) increment_counter(metric_name string) {
	r.record_metric(metric_name, 1.0)
}

func (metrics_registry* r) add_to_counter(metric_name string, value float32) {
	r.record_metric(metric_name, value)
}

func (metrics_registry* r) set_gauge(metric_name string, value float32) {
	r.record_metric(metric_name, value)
}

func (metrics_registry* r) record_histogram_value(metric_name string, value float32) {
	r.record_metric(metric_name, value)
}

func (metrics_registry* r) get_metric(metric_name string) (metric_series, bool) {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	series, exists := r.metrics[metric_name]
	return series, exists
}

func (metrics_registry* r) get_all_metrics() vec[metric_series] {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	result := make(vec[metric_series], 0, len(r.metrics))
	
	for _, series := range r.metrics {
		result = append(result, series)
	}
	
	return result
}

func (metrics_registry* r) collect_metrics() map[string]interface{} {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	collection := make(map[string]interface{})
	collection["collection_time"] = time.Now().Unix()
	collection["metric_count"] = r.metric_count
	
	component_stats := make(map[string]interface{})
	for component, count := range r.component_metric_counts {
		component_stats[component] = count
	}
	collection["components"] = component_stats
	
	metric_values := make(map[string]float32)
	for name, series := range r.metrics {
		if series.point_count > 0 {
			metric_values[name] = series.points[series.point_count-1].value
		}
	}
	collection["latest_values"] = metric_values
	
	r.last_collection_time = time.Now().UnixNano()
	
	return collection
}

func (metrics_registry* r) clear_old_points(retention_hours int32) {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	cutoff_time := time.Now().UnixNano() - int64(retention_hours)*3600*1000000000
	
	for name, series := range r.metrics {
		valid_points := make(vec[metric_point], 0)
		
		for point := range series.points {
			if point.timestamp > cutoff_time {
				valid_points = append(valid_points, point)
			}
		}
		
		series.points = valid_points
		series.point_count = int32(len(valid_points))
		r.metrics[name] = series
	}
}

func (metrics_registry* r) get_statistics() map[string]interface{} {
	r.mu.Lock()
	defer r.mu.Unlock()
	
	stats := make(map[string]interface{})
	stats["total_metrics"] = r.metric_count
	stats["total_points"] = 0
	
	total_points := int32(0)
	for _, series := range r.metrics {
		total_points = total_points + series.point_count
	}
	
	stats["total_points"] = total_points
	stats["average_points_per_metric"] = 0
	if r.metric_count > 0 {
		stats["average_points_per_metric"] = total_points / r.metric_count
	}
	
	return stats
}
