<?

eval(preg_replace("/#__PERLONLY_START__(.|\\n)*#__PERLONLY_END__/", "", implode('', file('../src/brancal.inc'))));

// seed with microseconds
function make_seed() {
    list($usec, $sec) = explode(' ', microtime());
    return (float) $sec + ((float) $usec * 100000);
}
srand(make_seed());

function is_time_free($id, $sql_time, $weekday = "", $cal_type = "", $date = "") {
	global $TEMPLATE;
	global $NO_CLASSES;
	global $BRANDEIS_DAYS;
	global $HOLIDAYS;
	global $extension;

	#echo "****CHECKING $weekday*****<br>\n";

	$phonelines = 1;
	$seconds_per_week = 604800;
	$wake_duration = 120;
	$max_snooze = 4;
	$snooze_duration = 540;

	/* This function determines if it's safe to add a wake-up call
	 * at a particular time.  If $date isn't set, we treat one-time
	 * wakes as if they were recurring wakes which go off on whatever
	 * day of the week their date is.  We do this because if a one-time
	 * wake would cause a conflict with a recurring wake on one particular
	 * day, well, that timeslot is not free.
	 *
	 * We convert the times of all applicable wakes into the format
	 * "seconds since the weekly epoch", which is "number of seconds
	 * since midnight on Sunday".  From now on, all math is modulo
	 * 604800 (number of seconds in a week), so things will wrap
	 * back around to Sunday instead of going from Saturday to
	 * Blurblesday.
	 *
	 * Then, we construct an array of intervals.  An interval is
	 * a set of (start_time, end_time, counter) tuples.  Each wake will result
	 * in five intervals, as per docs/timeslices.  We do the intervals
	 * for the timeslot we're checking, and then we go through the
	 * existing wakes, and every time one of the intervals overlaps
	 * with one of the intervals for the new wake, we increment
	 * the counter for that tuple.  If any of the wake-tuples have
	 * a count greater than the number of phonelines available to
	 * the system, the timeslot is not available.
	 *
	 * We use flock to guarantee that only one caller can be in this
	 * function at once, to avoid race conditions.
	 */

	$fp = fopen(".lock", "w+");
	if(!$fp || !flock($fp, LOCK_EX)) {
		echo $TEMPLATE["lock_error"];
		return 0;
	}

	//finepoch: (weekday-1) * 86400 + hours*60*60 + minutes*60

	/* First, get the one-time wakes.
	 * If this one is a one-timer, things are pretty straightforward, no weird holidays/Brandeis days/weekdays to deal with.
	 * If this one is recurring, we have to do various funky adjustments to exclude holidays/classless days, and in the
	 * case of Brandeis calendar, compensate for Brandeis Mondays/Tuesdays/etc.
	 */
	if($date) {
		preg_match('/(\d+)-(\d+)-(\d+)/', $date, $date_matches);
		preg_match('/(\d+):(\d+)/', $sql_time, $time_matches);
		$weekday = strftime("%w", mktime($time_matches[1], $time_matches[2], 0, $date_matches[2], $date_matches[3], $date_matches[1])) + 1;

		$result = @mysql_query("SELECT wake_id, (DAYOFWEEK(date)-1)*86400 + HOUR(time)*60*60 + MINUTE(time)*60 AS 'fintime' FROM wakes ".
			"WHERE wake_id != $id AND NOT ISNULL(date) AND (DAYOFYEAR(date) - DAYOFYEAR('$date')) % 366 < 7");
	} else {
		preg_match('/(\d+):(\d+)/', $sql_time, $time_matches);
		if($cal_type == "normal") {
			$result = @mysql_query("SELECT wake_id, (DAYOFWEEK(date)-1)*86400 + HOUR(time)*60*60 + MINUTE(time)*60 AS 'fintime' FROM wakes ".
				"WHERE wake_id != $id AND NOT ISNULL(date)");
		} else if($cal_type == "holidays") {
			$holidays = array_keys($HOLIDAYS);
			for($i = 0; $i < sizeof($holidays); $i++) $holidays[$i] = "'$holidays[$i]'";
			$result = @mysql_query("SELECT wake_id, (DAYOFWEEK(date)-1)*86400 + HOUR(time)*60*60 + MINUTE(time)*60 AS 'fintime' FROM wakes ".
				"WHERE wake_id != $id AND NOT ISNULL(date) AND date NOT IN (".implode(",",$holidays).")");
		} else {
			$no_classes = array_keys($NO_CLASSES);
			for($i = 0; $i < sizeof($no_classes); $i++) $no_classes[$i] = "'$no_classes[$i]'";

			$case = "CASE date";
			while(list($bdate, $bday) = each($BRANDEIS_DAYS)) $case .= " WHEN '$bdate' THEN $bday";
			$case .= " ELSE DAYOFWEEK(date) END";
			reset($BRANDEIS_DAYS);

			#echo "Doing query <tt>SELECT ($case - 1)*86400 + HOUR(time)*60*60 + MINUTE(time)*60 AS 'fintime' FROM wakes ".
				"WHERE wake_id != $id AND NOT ISNULL(date) AND date NOT IN (".implode(",",$no_classes).")</tt><br>\n";

			$result = @mysql_query("SELECT wake_id, ($case - 1)*86400 + HOUR(time)*60*60 + MINUTE(time)*60 AS 'fintime' FROM wakes ".
				"WHERE wake_id != $id AND NOT ISNULL(date) AND date NOT IN (".implode(",",$no_classes).")");
		}
	}
	if(!$result) {
		flock($fp, LOCK_UN);
		fclose($fp);
		db_error();
	}

	#echo "fin epoch: $weekday, $time_matches[1], $time_matches[2]<br>\n";
	$fintime = ($weekday-1) * 86400 + $time_matches[1]*60*60 + $time_matches[2]*60;
	$wake_intervals = _finepoch_intervals($fintime, $seconds_per_week, $wake_duration, $max_snooze, $snooze_duration);

	$okay = 1;

	//Get the one-shots
	while($row = mysql_fetch_row($result)) {
		if(_finepoch_check($phonelines, $wake_intervals, _finepoch_intervals($row[1], $seconds_per_week, $wake_duration, $max_snooze, $snooze_duration))) {
			#echo "Conflict with wake $row[0]<br>\n";
			$okay = 0;
			break;
		}
	}

	/* Now, we get the recurring wakes.
	 * Again, we have to make adjustments for calendar oddities in recurring wakes.
	 * The worst case is when this wake, the one we're checking availability for,
	 * is recurring.  Since a Monday in the Brandeis calendar can fall on any
	 * day of the week in the other calendars (damn you, Brandeis Mondays!),
	 * we have to assume that all wakes for calendar-types other than Brandeis
	 * can potentially happen on the same day as a Brandeis wake, and vice versa.
	 */
	if($okay) {
		$weekday_names = array("", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
		$weekday_name = $weekday_names[$weekday];
		if(isset($BRANDEIS_DAYS[$date]))
			$brandeis_weekday_name = $weekday_names[$BRANDEIS_DAYS[$date]];
		else
			$brandeis_weekday_name = $weekday_name;

		if($date) {
			$query = "SELECT wake_id, ($weekday-1)*86400 + HOUR(time)*60*60 + MINUTE(time)*60 AS 'fintime' FROM wakes " .
				"WHERE wake_id != $id AND ISNULL(date) AND (".
				"(cal_type='normal' AND (FIND_IN_SET('$weekday_name',std_weekdays)>0 OR FIND_IN_SET('$weekday_name',cur_weekdays)>0))";
			if(!isset($HOLIDAYS[$date])) $query .= " OR (cal_type='holidays' AND (FIND_IN_SET('$weekday_name',std_weekdays)>0 OR FIND_IN_SET('$weekday_name',cur_weekdays)>0))";
			if(!isset($NO_CLASSES[$date])) $query .= " OR (cal_type='Brandeis' AND (FIND_IN_SET('$brandeis_weekday_name',std_weekdays)>0 OR FIND_IN_SET('$brandeis_weekday_name',cur_weekdays)>0))";
			$query .= ")";

			#echo "Doing query <tt>$query</tt><br />\n";
			$result = @mysql_query($query);
		} else {
			$query = "SELECT wake_id, ($weekday-1)*86400 + HOUR(time)*60*60 + MINUTE(time)*60 AS 'fintime' FROM wakes " .
				"WHERE wake_id != $id AND ISNULL(date) AND (";
			if($cal_type == "Brandeis") {
				$query .= "cal_type='normal' OR cal_type='holidays'";
				$query .= " OR (cal_type='Brandeis' AND (FIND_IN_SET('$brandeis_weekday_name',std_weekdays)>0 OR FIND_IN_SET('$brandeis_weekday_name',cur_weekdays)>0))";
			} else {
				$query .= "cal_type='Brandeis'";
				$query .= " OR ((cal_type='normal' OR cal_type='holidays') AND (FIND_IN_SET('$brandeis_weekday_name',std_weekdays)>0 OR FIND_IN_SET('$brandeis_weekday_name',cur_weekdays)>0))";
			}
			$query .= ")";

			#echo "Doing query <tt>$query</tt><br />\n";
			$result = @mysql_query($query);
		}

		if(!$result) {
			flock($fp, LOCK_UN);
			fclose($fp);
			db_error();
		}

		while($row = mysql_fetch_row($result)) {
			if(_finepoch_check($phonelines, $wake_intervals, _finepoch_intervals($row[1], $seconds_per_week, $wake_duration, $max_snooze, $snooze_duration))) {
				#echo "Conflict with wake $row[0]<br>\n";
				$okay = 0;
				break;
			}
		}	
	}

	flock($fp, LOCK_UN);
	fclose($fp);

	return $okay;
}

function _finepoch_check($phonelines, &$wake_intervals, $cur_intervals) {
	for($j = 0; $j < sizeof($cur_intervals); $j++) {
		for($i = 0; $i < sizeof($wake_intervals); $i++) {
			#echo "Does (".$cur_intervals[$j][0].", ".$cur_intervals[$j][1].") overlap (".$wake_intervals[$i][0].", ".$wake_intervals[$i][1].")?<br>\n";
			if(
				($cur_intervals[$j][0] >= $wake_intervals[$i][0] && $cur_intervals[$j][1] <= $wake_intervals[$i][1]) ||
				($cur_intervals[$j][1] >= $wake_intervals[$i][0] && $cur_intervals[$j][1] <= $wake_intervals[$i][1])
			) {
				if(++$wake_intervals[$i][2] >= $phonelines) {
					return 1;
				}
			}
		}
	}

	return 0;
}

function _finepoch_intervals($fintime, $seconds_per_week, $wake_duration, $max_snooze, $snooze_duration) {
	$ret = array();
	//intervals == sum(n=0->4): C(t-n*11*60, (t+120)-n*9*60)

	for($i = 0; $i <= $max_snooze; $i++) {
		$ret[$i] = array($fintime + $i*$snooze_duration, $fintime+$wake_duration + $i*($snooze_duration+$wake_duration), 0);
		#echo "<tt>Got interval (".$ret[$i][0].", ".$ret[$i][1].")</tt><br />\n";
	}
	#echo "<tt>=======</tt><br />\n";

	return $ret;
}

function db_error() {
	global $TEMPLATE;
	echo preg_replace("/__ERROR__/", "Couldn't connect: " . mysql_error(), $TEMPLATE["db_error"]);
	do_end();
}

function log_ext($extension, $event, $result, $data = "") {
	if(!$data || $result == "success")
		$data = "NULL";
	else
		$data = "'$data'";

	if(!mysql_query(sprintf(
	   "INSERT INTO log_ext (extension, event, result, data, time, ip) VALUES ('%s', '%s', '%s', %s, NOW(), '%s')",
	                          $extension, $event, $result, $data, getenv("REMOTE_ADDR")))) db_error();
}

function log_wake($wake_id, $extension, $event, $result, $data = "") {
	if(!$data || $result == "success")
		$data = "NULL";
	else
		$data = "'$data'";

	if(!mysql_query(sprintf(
	   "INSERT INTO log_wake (wake_id, extension, event, result, data, start_time, end_time, ip) VALUES ('%s', '%s', '%s', '%s', %s, NOW(), NOW(), '%s')",
	                          $wake_id, $extension, $event, $result, $data, getenv("REMOTE_ADDR")))) db_error();
}

function extension_ok($extension) {
	global $TEMPLATE;
	if(!preg_match('/^[69][0-9]{4}$/', $extension)) {
		echo $TEMPLATE["extension_invalid"];
		return 0;
	} else if(in_array($extension, array(
		'62000', '62222', '63000', '63333', '65000'
	))) {
		echo $TEMPLATE["extension_forbidden"];
		return 0;
	} else {
		return 1;
	}
}

function pin_ok($extension, $pin, $newpin = 0) {
	global $TEMPLATE;
	global $extension_ok;

	if(!extension_ok($extension)) return 0;
	$ok = 0;
	$error = "";

	if(!preg_match('/^[0-9]{0,4}$/', $pin)) {
		if(!$newpin) {
			echo $TEMPLATE["pin_invalid"];
			$error = "pin_invalid";
	} else {
			echo $TEMPLATE["pin_set_new_invalid"];
			return 0;
		}
	} else {
		if($newpin) {
			if(!$pin) {
				echo $TEMPLATE["pin_set_new_invalid"];
				return 0;
			} else {
				return 1;
			}
		}

		$result = mysql_query(sprintf("SELECT pin FROM prefs WHERE extension='%s'", $extension));
		if(!$result) db_error();

		$row = mysql_fetch_array($result, MYSQL_NUM);
		if(!$row || !$row[0]) {
			$result = mysql_query(sprintf("SELECT COUNT(*) FROM log_ext WHERE ip='%s' AND event='getwakes' AND result='failure' AND data='gen_pin' AND UNIX_TIMESTAMP() - UNIX_TIMESTAMP(time) <= 3600", 
					getenv("REMOTE_ADDR")));
			if(!$result) db_error();
			$log_row = mysql_fetch_row($result);

			echo $TEMPLATE["viewcalls_start_noext"];
			if($log_row[0] >= 3) {
				echo $TEMPLATE["too_many_newpins"];
				log_ext($extension, "getwakes", "failure", "too_many_newpins");
			} else {
				$pin = "";
				for($i = 0; $i < 4; $i++) $pin .= rand(0, 9);
				if(!$row) {
					if(!mysql_query("INSERT INTO prefs (extension, pin, forgot_pin) VALUES ('$extension', '$pin', 1)")) db_error();
				} else {
					if(!mysql_query("UPDATE prefs SET pin='$pin', forgot_pin=1 WHERE extension='$extension'")) db_error();
				}

				echo $TEMPLATE["no_pin"];
				echo "<p>(But since we don't actually make calls yet, I'll just tell you that the PIN is $pin.)</p>\n";
				log_ext($extension, "getwakes", "failure", "gen_pin");
			}
			$extension_ok = 0;
			do_end();
		} else {
			$goodpin = $row[0];

			$result = mysql_query(sprintf("SELECT COUNT(*), extension, ip FROM log_ext WHERE (extension='%s' OR ip='%s') AND event='getwakes' AND result='failure' AND data='pin_error' AND UNIX_TIMESTAMP() - UNIX_TIMESTAMP(time) <= 3600 GROUP BY extension, ip HAVING COUNT(extension) >= 2", 
					$extension, getenv("REMOTE_ADDR")));
			if(!$result) db_error();

			$count = 0;
			$lockout = 0;
			while($row = mysql_fetch_array($result, MYSQL_NUM)) {
				if($row[0] >= 3) {
					$count++;
					if($row[1] == $extension && $row[2] == getenv("REMOTE_ADDR")) {
						$lockout = 2;
						break;
					}
				} else if($row[0] == 2) {
					$lockout = 1;
				}
			}

			if($count > 1) $lockout = 2;

			if($lockout == 2) {
				echo $TEMPLATE["pin_bruteforce"];
				$error = "pin_bruteforce";
			} else if($pin != $goodpin) {
				if($lockout) echo $TEMPLATE["pin_bruteforce_warn"];
				echo $TEMPLATE["pin_error"];
				$error = "pin_error";
			} else {
				$ok = 1;
			}
		}
	}

	log_ext($extension, "getwakes", $ok ? "success" : "failure", $error);

	return $ok;
}

// 22:00:04 -> ("10:00", "PM")
function time_to_user($sql_time) {
	if(!preg_match('/^(\d\d):(\d\d):\d\d$/', $sql_time, $matches)) return "";
	$hours = $matches[1];
	$minutes = $matches[2];
	if($hours == 0) {
		return array(sprintf("%d:%02d", 12, $minutes), "AM");
	} else if($hours < 12) {
		return array(sprintf("%d:%02d", $hours, $minutes), "AM");
	} else if($hours == 12) {
		return array(sprintf("%d:%02d", $hours, $minutes), "PM");
	} else if($hours < 24) {
		$hours -= 12;
		return array(sprintf("%d:%02d", $hours, $minutes), "PM");
	} else if($hours == 24) { //24:00:00
		return array("12:00", "AM");
	} else {
		return array("", "");
	}
}

// (10:00, 'PM') -> 22:00:00
function time_to_sql($user_time, $ampm) {
	if(!preg_match('/^(\d?\d):(\d\d)$/', $user_time, $matches)) return "";
	if($ampm != "AM" && $ampm != "PM") return "";
	$hours = $matches[1];
	$minutes = $matches[2];
	if($hours == 12 && $ampm == "AM") {
		return "00:$minutes:00";
	} else if($hours < 12 && $ampm == "AM") {
		return "$hours:$minutes:00";
	} else if($hours == 12 && $ampm == "PM") {
		return "$hours:$minutes:00";
	} else if($hours < 12 && $ampm == "PM") {
		$hours += 12;
		return "$hours:$minutes:00";
	} else { //hours > 12
		return "";
	}
}

// YYYY-01-02 -> ("3/20")
function date_to_user($sql_date) {
	global $months;
	if(!preg_match('/^\d\d\d\d-(\d\d)-(\d\d)$/', $sql_date, $matches)) return "";
	$month = 0+$matches[1];
	$day = $matches[2];
	return "$month/$day";
}

// ("Jan", 2) -> YYYY-01-02
function date_to_sql($user_date, $sql_time) {
	global $inv_months;
	if(!preg_match('/^(\d{1,2})\/(\d\d)$/', $user_date, $matches)) return "";
	if($matches[1] < 1 || $matches[1] > 12 || $matches[2] < 1 || $matches[2] > 31) return "";

	$year = strftime("%Y");
	$cur_time = time();
	$sql_time = preg_match('/(\d+):(\d+)/', $sql_time, $time_matches);
	$user_time = mktime($time_matches[1], $time_matches[2], 0, $matches[1], $matches[2], $year);
	if($cur_time > $user_time) $year++;
	
	return sprintf("%04d-%02d-%02d", $year, $matches[1], $matches[2]);
}

function do_end() {
	global $TEMPLATE;
	global $page;
	global $extension_ok;

	if($extension_ok) {
		echo $TEMPLATE[$page."_end"];
	} else {
		echo $TEMPLATE["viewcalls_end_noext"];
	}
	echo $TEMPLATE["page_end"];
	exit;
}

function check_extension_pin() {
	global $extension_ok;
	global $extension;
	global $pin;
	global $savepin;

	$extension_ok = 0;
	$extension = "";
	$pin = "";
	$savepin = 0;

	if(isset($_COOKIE["finnegan-extension"])) $extension = $_COOKIE["finnegan-extension"];
	if(isset($_POST["extension"])) $extension = $_POST["extension"];

	if(isset($_COOKIE["finnegan-pin"])) $pin = $_COOKIE["finnegan-pin"];
	if(isset($_POST["pin"])) $pin = $_POST["pin"];

	if(isset($_COOKIE["finnegan-savepin"]) && $_COOKIE["finnegan-savepin"] == 1) $savepin = 1;
	if(isset($_POST["savepin"]) && $_POST["savepin"] == 1) $savepin = 1;

	if($extension) {
		setcookie("finnegan-extension", $extension, time()+60*60*24*365);
		if(pin_ok($extension, $pin)) {
			$extension_ok = 1;

			if($savepin) {
				setcookie("finnegan-pin", $pin, time()+60*60*24*365);
				setcookie("finnegan-savepin", "1", time()+60*60*24*365);
			} else {
				setcookie("finnegan-pin", $pin);
			}
		} else if(extension_ok($extension)) {
			setcookie("finnegan-extension", $extension, time()+60*60*24*365);
		}
	}
}

?>
