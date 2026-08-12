package main
use neurx.runtime.io.{runtime_env_get, runtime_run_command, runtime_shell_escape}
use std.io.println
func schema_sql(string password) string {
    "CREATE DATABASE IF NOT EXISTS `neurx` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\n" +
    "CREATE USER IF NOT EXISTS 'neurx'@'%' IDENTIFIED BY '" + password + "';\n" +
    "GRANT ALL PRIVILEGES ON `neurx`.* TO 'neurx'@'%';\n" +
    "FLUSH PRIVILEGES;\n" +
    "USE `neurx`;\n" +
    "CREATE TABLE IF NOT EXISTS `user` (`id` BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY, `phone` VARCHAR(32) NOT NULL UNIQUE, `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;\n" +
    "ALTER TABLE `user` ADD COLUMN IF NOT EXISTS `phone` VARCHAR(32) DEFAULT NULL, DROP COLUMN IF EXISTS `password`, DROP COLUMN IF EXISTS `email`, DROP COLUMN IF EXISTS `username`, DROP COLUMN IF EXISTS `password_hash`, DROP COLUMN IF EXISTS `remember_token`, DROP COLUMN IF EXISTS `remember_expires`, DROP COLUMN IF EXISTS `last_login`;\n" +
    "ALTER TABLE `user` MODIFY COLUMN `phone` VARCHAR(32) NOT NULL;\n"
}


func main() {
    string password = runtime_env_get("NEURX_DB_PASSWORD", "")
    if password == "" {
        println("NEURX_DB_PASSWORD must be set")
        return 1
    }
    string host = runtime_env_get("NEURX_DB_HOST", "127.0.0.1")
    string port = runtime_env_get("NEURX_DB_PORT", "3306")
    string admin = runtime_env_get("NEURX_DB_ADMIN", "root")
    string sql = schema_sql(password)
    string command = "printf %s " + runtime_shell_escape(sql)
    command = command + " | mysql -h " + runtime_shell_escape(host)
    command = command + " -P " + runtime_shell_escape(port)
    command = command + " -u " + runtime_shell_escape(admin)
    if !runtime_run_command(command).ok {
        println("MySQL schema initialization failed")
        return 1
    }
    println("NeurX MySQL schema initialized")
    0
}

