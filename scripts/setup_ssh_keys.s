package main

use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape, runtime_run_command_output}
use std.io.println

func main() int {
    string hosts = runtime_env_get("WORKER_HOSTS", "")
    if hosts == "" {
        println("Usage: set WORKER_HOSTS='root@host1 root@host2' and run this script")
        return 1
    }

    string home = runtime_env_get("HOME", "/root")
    string key_path = runtime_env_get("KEY_PATH", home + "/.ssh/neurx_id_rsa")
    string pub_key = key_path + ".pub"
    string worker_pass = runtime_env_get("WORKER_PASS", "")

    // Ensure key exists
    if !runtime_run_command("test -f " + runtime_shell_escape(key_path)).ok {
        _ = runtime_run_command("mkdir -p " + runtime_shell_escape(home + "/.ssh"))
        string gen_cmd = "ssh-keygen -t rsa -b 4096 -f " + runtime_shell_escape(key_path) + " -N '' -C neurx-ssh-key"
        if !runtime_run_command(gen_cmd).ok {
            println("[ERROR] failed to generate ssh key: " + gen_cmd)
            return 2
        }
    } else {
        println("Using existing key: " + key_path)
    }

    if !runtime_run_command("test -f " + runtime_shell_escape(pub_key)).ok {
        println("[ERROR] public key not found: " + pub_key)
        return 3
    }

    // Build a shell loop to copy the key to each host (uses ssh-copy-id if available)
    string sh_cmd = "hosts=\"" + hosts + "\"; for host in $hosts; do echo Copying key to $host; "

    // prefer ssh-copy-id, support sshpass when WORKER_PASS provided
    sh_cmd = sh_cmd + "if command -v ssh-copy-id >/dev/null 2>&1; then "
    if worker_pass != "" {
        sh_cmd = sh_cmd + "if command -v sshpass >/dev/null 2>&1; then sshpass -p '" + worker_pass + "' ssh-copy-id -i " + runtime_shell_escape(pub_key) + " -o StrictHostKeyChecking=no $host; else ssh-copy-id -i " + runtime_shell_escape(pub_key) + " -o StrictHostKeyChecking=no $host || true; fi; "
    } else {
        sh_cmd = sh_cmd + "ssh-copy-id -i " + runtime_shell_escape(pub_key) + " -o StrictHostKeyChecking=no $host || true; "
    }
    sh_cmd = sh_cmd + "else "
    if worker_pass != "" {
        sh_cmd = sh_cmd + "if command -v sshpass >/dev/null 2>&1; then sshpass -p '" + worker_pass + "' ssh -o StrictHostKeyChecking=no $host \"mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys\" < " + runtime_shell_escape(pub_key) + "; else cat " + runtime_shell_escape(pub_key) + " | ssh -o StrictHostKeyChecking=no $host 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'; fi; "
    } else {
        sh_cmd = sh_cmd + "cat " + runtime_shell_escape(pub_key) + " | ssh -o StrictHostKeyChecking=no $host 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys'; "
    }
    sh_cmd = sh_cmd + "fi; ssh -o BatchMode=yes -o ConnectTimeout=5 $host 'echo SSH_OK' || echo \"SSH to $host failed\"; done"

    println("Distributing key to hosts...")
    string out = runtime_run_command_output(sh_cmd)
    println(out)

    println("Done.")
    0
}
