CREATE TABLE prefs (
	extension CHAR(5) NOT NULL PRIMARY KEY,
	pin VARCHAR(4) NULL,
	forgot_pin BIT NOT NULL DEFAULT 0
);

CREATE TABLE wakes (
	wake_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	extension CHAR(5) NOT NULL,
	time TIME NOT NULL,
	message INT UNSIGNED NOT NULL DEFAULT 0,
	date DATE NULL,
	std_weekdays SET('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun') NULL,
	cur_weekdays SET('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun') NULL,
	cal_type SET('normal', 'holidays', 'Brandeis') NULL,
	verified BIT NOT NULL DEFAULT 0,
	verify_tries TINYINT NOT NULL DEFAULT 0,
	snooze_interval INT NOT NULL DEFAULT 9,
	snooze_time TIME NULL,
	snooze_count INT NOT NULL DEFAULT 0,
	trigger_time DATETIME NULL,
	INDEX (time),
	INDEX (date),
	INDEX (std_weekdays),
	INDEX (cur_weekdays),
	INDEX (snooze_time),
	INDEX (verified),
	INDEX (extension)
);

CREATE TABLE log_wake (
	log_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	wake_id INT UNSIGNED NOT NULL,
	extension CHAR(5) NOT NULL,
	event ENUM('create', 'delete', 'edit', 'activate', 'verify') NOT NULL,
	result ENUM('success', 'failure') NULL,
	start_time DATETIME NOT NULL,
	end_time DATETIME NULL,
	data VARCHAR(255) NULL,
	ip VARCHAR(15) NULL,
	INDEX (extension),
	INDEX (wake_id),
	INDEX (event),
	INDEX (result),
	INDEX (start_time),
	KEY (log_id)
);

CREATE TABLE log_ext (
	log_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	extension CHAR(5) NOT NULL,
	event ENUM('getwakes', 'setpin', 'delcookie') NOT NULL,
	result ENUM('success', 'failure') NULL,
	time DATETIME NOT NULL,
	data VARCHAR(255) NULL,
	ip VARCHAR(15) NULL,
	INDEX (extension),
	INDEX (event),
	INDEX (result),
	INDEX (time),
	KEY (log_id)
);

