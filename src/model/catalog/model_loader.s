package models
import (
	"crypto/md5"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"sync"
	"time"
)
type model_loader_status int32
const (
	LOADER_STATUS_IDLE model_loader_status = iota
	LOADER_STATUS_LOADING
	LOADER_STATUS_VALIDATING
	LOADER_STATUS_COMPLETE
	LOADER_STATUS_ERROR
)
struct model_package {
	string package_id
	string model_id
	string model_name
	model_type model_type
	string version
	string path
	int64 size_bytes
	string checksum
	time.Time created_at
	string metadata_file
	string weights_file
	string config_file
	string tokenizer_file
	map[string]string additional_files
}

struct model_descriptor {
	string model_id
	string model_name
	model_type model_type
	string version
	string description
	string author
	string license
	float64 size_gb
	int64 parameters_count
	int32 vocabulary_size
	int32 max_seq_length
	default_device model_device_type
	default_precision model_precision_type
	[]model_device_type supported_devices
	[]model_precision_type supported_precisions
	[]model_capability capabilities
	[]string dependencies
	int32 recommended_batch_size
	float64 recommended_memory_gb
	[]string tags
	map[string]interface{} metadata
}

struct load_validation_result {
	bool valid
	[]string errors
	[]string warnings
	int64 validation_time_ms
}

struct model_loader {
	sync.Mutex mu
	status model_loader_status
	map[string]*model_package loaded_packages
	map[string]*model_package loading_packages
	[]string model_paths
	int64 total_load_attempts
	int64 total_load_failures
	int64 total_load_successes
	int32 max_concurrent_loads
	int32 current_loads
	bool cache_enabled
	string cache_dir
	int32 timeout_seconds
}

struct model_load_result {
	bool success
	string model_id
	string package_id
	*model_interface model_interface
	int64 load_time_ms
	string error_message
	[]string warnings
}

func create_model_loader() *model_loader {
	return *model_loader{
		status: LOADER_STATUS_IDLE,
		loaded_packages: make(map[string]*model_package),
		loading_packages: make(map[string]*model_package),
		model_paths: []string{},
		max_concurrent_loads: 4,
		cache_enabled: true,
		cache_dir: "/tmp/model_cache",
		timeout_seconds: 300,
	}
}

func (model_loader* loader) register_model_path(path string) error {
	loader.mu.Lock()
	defer loader.mu.Unlock()
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	if !info.IsDir() {
		return fmt.Errorf("path is not a directory: %s", path)
	}
	for _, p := range loader.model_paths {
		if p == path {
			return nil
		}
	}
	loader.model_paths = append(loader.model_paths, path)
	return nil
}

func (model_loader* loader) load_model(package_id string, model_type model_type, device model_device_type) *model_load_result {
	loader.mu.Lock()
	if loader.current_loads >= loader.max_concurrent_loads {
		loader.mu.Unlock()
		return *model_load_result{
			success: false,
			package_id: package_id,
			error_message: "max concurrent loads exceeded",
		}
	}
	loader.current_loads++
	loader.total_load_attempts++
	loader.status = LOADER_STATUS_LOADING
	loader.mu.Unlock()
	start_time := time.Now()
	pkg := loader.find_package_by_id(package_id)
	if pkg == nil {
		loader.mu.Lock()
		loader.current_loads--
		loader.total_load_failures++
		loader.mu.Unlock()
		return *model_load_result{
			success: false,
			package_id: package_id,
			error_message: fmt.Sprintf("package not found: %s", package_id),
		}
	}
	validation_result := loader.validate_model_package(pkg)
	if !validation_result.valid {
		loader.mu.Lock()
		loader.current_loads--
		loader.total_load_failures++
		loader.mu.Unlock()
		error_msg := "validation failed"
		if len(validation_result.errors) > 0 {
			error_msg = validation_result.errors[0]
		}
		return *model_load_result{
			success: false,
			package_id: package_id,
			error_message: error_msg,
			warnings: validation_result.warnings,
		}
	}
	model := create_model_interface(pkg.model_id, pkg.model_name, pkg.model_type)
	model.set_device(device)
	model.set_state(STATE_LOADED)
	loader.mu.Lock()
	loader.loaded_packages[package_id] = pkg
	loader.current_loads--
	loader.total_load_successes++
	loader.status = LOADER_STATUS_COMPLETE
	loader.mu.Unlock()
	load_time := int64(time.Since(start_time).Milliseconds())
	return *model_load_result{
		success: true,
		model_id: pkg.model_id,
		package_id: package_id,
		model_interface: model,
		load_time_ms: load_time,
	}
}

func (model_loader* loader) find_package_by_id(package_id string) *model_package {
	for _, path := range loader.model_paths {
		pkg_path := filepath.Join(path, package_id)
		if info, err := os.Stat(pkg_path); err == nil && info.IsDir() {
			return *model_package{
				package_id: package_id,
				path: pkg_path,
				metadata_file: filepath.Join(pkg_path, "config.json"),
				weights_file: filepath.Join(pkg_path, "model.safetensors"),
				tokenizer_file: filepath.Join(pkg_path, "tokenizer.json"),
				additional_files: make(map[string]string),
			}
		}
	}
	return nil
}

func (model_loader* loader) validate_model_package(model_package* pkg) *load_validation_result {
	result := *load_validation_result{
		valid: true,
		errors: []string{},
		warnings: []string{},
	}
	start_time := time.Now()
	if pkg == nil {
		result.valid = false
		result.errors = append(result.errors, "package is nil")
		return result
	}
	if pkg.path == "" {
		result.valid = false
		result.errors = append(result.errors, "package path is empty")
		return result
	}
	if info, err := os.Stat(pkg.path); err != nil || !info.IsDir() {
		result.valid = false
		result.errors = append(result.errors, fmt.Sprintf("invalid package path: %s", pkg.path))
		return result
	}
	if _, err := os.Stat(pkg.metadata_file); err != nil {
		result.warnings = append(result.warnings, fmt.Sprintf("metadata file not found: %s", pkg.metadata_file))
	}
	if _, err := os.Stat(pkg.weights_file); err != nil {
		result.valid = false
		result.errors = append(result.errors, fmt.Sprintf("weights file not found: %s", pkg.weights_file))
	}
	if _, err := os.Stat(pkg.tokenizer_file); err != nil {
		result.warnings = append(result.warnings, fmt.Sprintf("tokenizer file not found: %s", pkg.tokenizer_file))
	}
	file_info, _ := os.Stat(pkg.weights_file)
	if file_info != nil {
		pkg.size_bytes = file_info.Size()
	}
	result.validation_time_ms = int64(time.Since(start_time).Milliseconds())
	return result
}

func (model_loader* loader) calculate_checksum(file_path string) (string, error) {
	data, err := ioutil.ReadFile(file_path)
	if err != nil {
		return "", err
	}
	hash := md5.Sum(data)
	return fmt.Sprintf("%x", hash), nil
}

func (model_loader* loader) unload_model(package_id string) error {
	loader.mu.Lock()
	defer loader.mu.Unlock()
	delete(loader.loaded_packages, package_id)
	delete(loader.loading_packages, package_id)
	return nil
}

func (model_loader* loader) reload_model(package_id string, device model_device_type) *model_load_result {
	loader.unload_model(package_id)
	return loader.load_model(package_id, TYPE_CUSTOM, device)
}

func (model_loader* loader) get_loaded_models() []string {
	loader.mu.Lock()
	defer loader.mu.Unlock()
	models := make([]string, 0, len(loader.loaded_packages))
	for package_id := range loader.loaded_packages {
		models = append(models, package_id)
	}
	return models
}

func (model_loader* loader) has_model(package_id string) bool {
	loader.mu.Lock()
	defer loader.mu.Unlock()
	_, exists := loader.loaded_packages[package_id]
	return exists
}

func (model_loader* loader) get_model_package(package_id string) *model_package {
	loader.mu.Lock()
	defer loader.mu.Unlock()
	return loader.loaded_packages[package_id]
}

func (model_loader* loader) get_loader_stats() map[string]interface{} {
	loader.mu.Lock()
	defer loader.mu.Unlock()
	stats := make(map[string]interface{})
	stats["status"] = loader.status
	stats["total_load_attempts"] = loader.total_load_attempts
	stats["total_load_failures"] = loader.total_load_failures
	stats["total_load_successes"] = loader.total_load_successes
	stats["loaded_models_count"] = len(loader.loaded_packages)
	stats["current_loads"] = loader.current_loads
	stats["max_concurrent_loads"] = loader.max_concurrent_loads
	stats["model_paths"] = loader.model_paths
	return stats
}

func (model_loader* loader) set_max_concurrent_loads(max_loads int32) {
	loader.mu.Lock()
	defer loader.mu.Unlock()
	loader.max_concurrent_loads = max_loads
}

func (model_loader* loader) set_cache_dir(cache_dir string) {
	loader.mu.Lock()
	defer loader.mu.Unlock()
	loader.cache_dir = cache_dir
}

func (model_loader* loader) enable_cache(enabled bool) {
	loader.mu.Lock()
	defer loader.mu.Unlock()
	loader.cache_enabled = enabled
}
