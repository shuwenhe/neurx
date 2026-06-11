-- MySQL initialization script for neurx

-- Initialize neurx database, user, and login table
-- Run this as a privileged MySQL user (e.g., root)

-- Note: if your MySQL server listens on port 33061,
-- run the client with `-P 33061 -h 127.0.0.1`
-- before executing this script.

CREATE DATABASE IF NOT EXISTS `neurx` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'neurx'@'%' IDENTIFIED BY 'Neurx@_2026..';

GRANT ALL PRIVILEGES ON `neurx`.* TO 'neurx'@'%';

FLUSH PRIVILEGES;

USE `neurx`;

-- Table for user login information
CREATE TABLE IF NOT EXISTS `user` (
  `id` BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `phone` VARCHAR(32) NOT NULL UNIQUE,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Backward-compatible migration for older tables.
-- This converges the table to exactly: id, phone, created_at.
ALTER TABLE `user`
  ADD COLUMN IF NOT EXISTS `phone` VARCHAR(32) DEFAULT NULL,
  DROP COLUMN IF EXISTS `password`,
  DROP COLUMN IF EXISTS `email`,
  DROP COLUMN IF EXISTS `username`,
  DROP COLUMN IF EXISTS `password_hash`,
  DROP COLUMN IF EXISTS `remember_token`,
  DROP COLUMN IF EXISTS `remember_expires`,
  DROP COLUMN IF EXISTS `last_login`;

ALTER TABLE `user`
  MODIFY COLUMN `phone` VARCHAR(32) NOT NULL;

-- Verification query:
-- SELECT id, phone, created_at
-- FROM neurx.`user`;
