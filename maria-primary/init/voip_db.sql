-- Create the database
CREATE DATABASE IF NOT EXISTS voip_db;

-- Use the newly created database
USE voip_db;

-- Create the calls table
CREATE TABLE calls (
    id INT AUTO_INCREMENT PRIMARY KEY,
    caller_id VARCHAR(20) NOT NULL,
    callee_id VARCHAR(20) NOT NULL,
    call_start_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    call_end_time DATETIME,
    duration INT GENERATED ALWAYS AS (TIMESTAMPDIFF(SECOND, call_start_time, call_end_time)) STORED,
    call_status ENUM('connected', 'failed', 'busy', 'no_answer') NOT NULL,
    codec_used VARCHAR(50),
    call_direction ENUM('inbound', 'outbound') NOT NULL,
    call_cost DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO calls (caller_id, callee_id, call_end_time, call_status, codec_used, call_direction, call_cost)
VALUES
    ('1234567890', '0987654321', '2024-01-01 12:15:30', 'connected', 'G.711', 'outbound', 0.10),
    ('5551234567', '4449876543', NULL, 'no_answer', 'G.729', 'inbound', 0.00),
    ('7890123456', '5678901234', '2024-01-01 14:45:00', 'connected', 'G.711', 'outbound', 0.25),
    ('3216549870', '8765432109', '2024-01-01 15:00:00', 'failed', NULL, 'inbound', 0.00);
