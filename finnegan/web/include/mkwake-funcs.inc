<?

function is_time_free($id, $sql_time, $weekday = "", $cal_type = "", $date = "") {
	global $FinneganConfig;
	global $TEMPLATE;
	global $NO_CLASSES;
	global $BRANDEIS_DAYS;
	global $HOLIDAYS;
	global $extension;
	global $path;

	if(!isset($BRANDEIS_DAYS)) {
		eval(preg_replace("/#__PERLONLY_START__(.|\\n)*?#__PERLONLY_END__/", "", implode('', file("$path/../etc/brancal.inc"))));
	}


	#echo "****CHECKING $weekday*****<br>\n";

	$phonelines = sizeof($FinneganConfig->phonelines) * 2;
	$seconds_per_week = 604800;
	$wake_duration = $FinneganConfig->max_wake_duration;
	$max_snooze = $FinneganConfig->max_snooze_count;
	$snooze_duration = $FinneganConfig->snooze_interval;

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

	$fp = fopen("$path/.lock", "w+");
	if(!$fp || !flock($fp, LOCK_EX)) {
		echo $TEMPLATE["global"]["lock_error"];
		return 0;
	}

	if(!$id) $id = "0";

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
				"(cal_type='normal' AND FIND_IN_SET('$weekday_name',weekdays)>0)";
			if(!isset($HOLIDAYS[$date])) $query .= " OR (cal_type='holidays' AND FIND_IN_SET('$weekday_name',weekdays)>0)";
			if(!isset($NO_CLASSES[$date])) $query .= " OR (cal_type='Brandeis' AND FIND_IN_SET('$brandeis_weekday_name',weekdays)>0)";
			$query .= ")";

			$result = @mysql_query($query);
		} else {
			$query = "SELECT wake_id, ($weekday-1)*86400 + HOUR(time)*60*60 + MINUTE(time)*60 AS 'fintime' FROM wakes " .
				"WHERE wake_id != $id AND ISNULL(date) AND (";
			if($cal_type == "Brandeis") {
				$query .= "cal_type='normal' OR cal_type='holidays'";
				$query .= " OR (cal_type='Brandeis' AND FIND_IN_SET('$brandeis_weekday_name',weekdays)>0)";
			} else {
				$query .= "cal_type='Brandeis'";
				$query .= " OR ((cal_type='normal' OR cal_type='holidays') AND FIND_IN_SET('$brandeis_weekday_name',weekdays)>0)";
			}
			$query .= ")";

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

?>
