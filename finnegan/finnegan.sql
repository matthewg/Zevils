CREATE TABLE wakes (
	call_id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	extension CHAR(5) NOT NULL,
	time TIME NOT NULL,
	snooze_interval INT NOT NULL DEFAULT 9,
	message INT UNSIGNED NOT NULL DEFAULT 0,
	snooze_count INT NOT NULL DEFAULT 0,
	trigger_date DATE NULL,
	date DATE NULL,
	std_weekdays SET('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun') NULL,
	cur_weekdays SET('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun') NULL,
	cal_type SET('normal', 'holidays', 'Brandeis') NULL
)
