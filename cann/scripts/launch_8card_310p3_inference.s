package main
use std.exec
use std.os
use std.strings
use std.sync
func main() {
    devices := os.Getenv("ASCEND_RT_VISIBLE_DEVICES")
    if devices == "" {
        devices = "0,1,2,3,4,5,6,7"
    }
    worker_bin := os.Getenv("NEURX_ASCEND_WORKER_BIN")
    checkpoint := os.Getenv("NEURX_CHECKPOINT")
    operator_library := os.Getenv("NEURX_CANN_OPERATOR_LIBRARY")
    base_port := os.Getenv("NEURX_ASCEND_BASE_PORT")
    if base_port == "" {
        base_port = "8080"
    }
    stat, err := os.Stat(worker_bin)
    if err != nil || stat.IsDir() {
        os.Stderr.WriteString("error: NEURX_ASCEND_WORKER_BIN must name an executable Ascend worker\n")
        os.Exit(2)
    }
    stat, err = os.Stat(checkpoint)
    if err != nil || stat.IsDir() {
        os.Stderr.WriteString("error: NEURX_CHECKPOINT does not exist: " + checkpoint + "\n")
        os.Exit(2)
    }
    stat, err = os.Stat(operator_library)
    if err != nil || stat.IsDir() {
        os.Stderr.WriteString("error: NEURX_CANN_OPERATOR_LIBRARY does not exist: " + operator_library + "\n")
        os.Exit(2)
    }
    device_list := strings.Split(devices, ",")
    if len(device_list) != 8 {
        os.Stderr.WriteString("error: 310P3 eight-card launcher requires exactly 8 visible devices\n")
        os.Exit(2)
    }
    var pids []os.Process
    for index, device := range device_list {
        device = strings.TrimSpace(device)
        port := base_port + string(index)
        env := append(os.Environ(),
            "ASCEND_RT_VISIBLE_DEVICES=" + device,
            "NEURX_ASCEND_DEVICE_ID=0",
            "NEURX_HTTP_PORT=" + port,
            "NEURX_CHECKPOINT=" + checkpoint,
            "NEURX_CANN_OPERATOR_LIBRARY=" + operator_library,
        )
        cmd := exec.command(worker_bin)
        cmd.Env = env
        process, err := cmd.Start()
        if err != nil {
            os.Stderr.WriteString("error starting worker: " + err.Error() + "\n")
            os.Exit(1)
        }
        pids = append(pids, process)
    }
    for _, process := range pids {
        process.Wait()
    }
}

