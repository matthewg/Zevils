<?

require "db-connect.inc";
require "template.inc";
require "common-funcs.inc";

$page = "viewcalls";

ob_start();
$dbh = get_dbh();
if(!$dbh) db_error();

check_extension_pin();

if(isset($_POST["op"]) && $_POST["op"] == "Log Out") {
	unset($_COOKIE["finnegan-extension"]);
	unset($_COOKIE["finnegan-pin"]);
	unset($_POST["extension"]);
	unset($_POST["pin"]);
	setcookie("finnegan-extension", "", time()-3600);
	setcookie("finnegan-pin", "", time()-3600);
	setcookie("finnegan-savepin", "", time()-3600);

	if(!mysql_query(sprintf("INSERT INTO log_ext (extension, event, result, time, ip) VALUES ('%s', '%s', '%s', NOW(), '%s')",
		$extension, "delcookie", "success", getenv("REMOTE_ADDR")))) db_error();
	$extension = "";
}

echo preg_replace("/__TITLE__/",
	"Finnegan: Wake-up Calls by the Brandeis University Student Union",
	$TEMPLATE["page_start"]
);

if($extension_ok) {
	echo $TEMPLATE["viewcalls_start"];

	if(!$dbh) db_error();



	if(isset($_POST["op"])) {
		$op = $_POST["op"];
		if($op == "Set PIN") {
			$oldpin = isset($_POST["oldpin"]) ? $_POST["oldpin"] : "";
			$pin1 = isset($_POST["pin1"]) ? $_POST["pin1"] : "";
			$pin2 = isset($_POST["pin2"]) ? $_POST["pin2"] : "";
			$error = "";
			if($oldpin != $pin) {
				echo $TEMPLATE["pin_set_old_error"];
				$error = "pin_set_old_error";
			} else if($pin1 != $pin2) {
				echo $TEMPLATE["pin_set_new_mismatch"];
				$error = "pin_set_new_mismatch";
			} else if(!pin_ok($extension, $pin1, 1)) {
				$error = "pin_set_new_invalid";
			} else {
				$result = mysql_query(sprintf("SELECT COUNT(*) FROM prefs WHERE extension='%s'",
						$extension));
				if(!$result) db_error();

				$row = mysql_fetch_array($result, MYSQL_NUM);
				$has_pref = $row[0];

				if($has_pref) {
					if(!mysql_query(sprintf("UPDATE prefs SET pin='%s' WHERE extension='%s'",
						$pin1, $extension))) db_error();
				} else {
					if(!mysql_query(sprintf("INSERT INTO prefs (extension, pin) VALUES ('%s', '%s')",
						$extension, $pin1))) db_error();
				}

				if($savepin) {
					setcookie("finnegan-pin", $pin1, time()+60*60*24*365);
				} else {
					setcookie("finnegan-pin", $pin1);
				}

				echo $TEMPLATE["pin_set_ok"];
			}

			if(!$error) {
				if(!mysql_query(sprintf("INSERT INTO log_ext (extension, event, result, time, ip) VALUES ('%s', '%s', '%s', NOW(), '%s')",
					$extension, "setpin", "success", getenv("REMOTE_ADDR")))) db_error();
			} else {
				if(!mysql_query(sprintf("INSERT INTO log_ext (extension, event, result, time, data, ip) VALUES ('%s', '%s', '%s', NOW(), '%s', '%s')",
					$extension, "setpin", "failure", $error, getenv("REMOTE_ADDR")))) db_error();
			}
		} else if($op == "Confirm Deletion" && isset($_POST["id"])) {
			while(list($id, $value) = each($_POST["id"])) {
				if(!preg_match('/^[0-9]+$/', $id)) unset($_POST["id"]);
			}
			$keys = implode(", ", array_keys($_POST["id"]));

			if(!mysql_query(sprintf("DELETE FROM wakes WHERE extension='%s' AND wake_id IN (%s)", $extension, $keys))) db_error();

			while(list($id, $value) = each($_POST["id"])) {
				if(!mysql_query(sprintf("INSERT INTO log_wake (wake_id, extension, event, result, start_time, end_time, ip) VALUES ('%s', '%s', '%s', '%s', NOW(), NOW(), '%s')",
					$id, $extension, "delete", "success", getenv("REMOTE_ADDR")))) db_error();
			}
		}
	}


	$result = mysql_query("SELECT wake_id, time, message, date, std_weekdays, cur_weekdays, cal_type FROM wakes WHERE extension='$extension' ORDER BY time");
	if(!$result) db_error();

	$count = mysql_num_rows($result);
	echo preg_replace("/__COUNT__/", $count, $TEMPLATE["wake_list_start"]);
	while($count && ($row = mysql_fetch_assoc($result))) {
		$delete = "";
		$delete_class = "";
		if(isset($_POST["op"]) && $_POST["op"] == "Delete marked wake-up calls" && isset($_POST["id"][$row["wake_id"]])) {
			$delete = "checked";
			$delete_class = 'class="wake-deleted"';
		}

		$time_array = time_to_user($row["time"]);
		if(!$time_array[0]) {
			echo preg_replace("/__DATE__/", $row["time"], $TEMPLATE["date_error"]);
			do_end();
		}
		$time = "$time_array[0] $time_array[1]";

		if($row["date"]) {
			$date = date_to_user($row["date"]);
			if(!$date) {
				echo preg_replace("/__DATE__/", $row["date"], $TEMPLATE["date_error"]);
				do_end();
			}

			echo preg_replace(
				array("/__DELETE_CLASS__/",
				      "/__ID__/",
				      "/__DELETE__/",
				      "/__TIME__/",
				      "/__MESSAGE__/",
				      "/__DATE__/"),
				array($delete_class,
				      $row["wake_id"],
				      $delete,
				      $time,
				      $row["message"],
				      $date),
				$TEMPLATE["wake_list_item_once"]
			);
		} else {
			$std_days = explode(",", $row["std_weekdays"]);
			$cur_days = explode(",", $row["cur_weekdays"]);
			$checkdays = array("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun");
			$days = array();
			$std_days_assoc = array();
			$cur_days_assoc = array();
			for($i = 0; $i < count($std_days); $i++) { $std_days_assoc[$std_days[$i]] = 1; }
			for($i = 0; $i < count($cur_days); $i++) { $cur_days_assoc[$cur_days[$i]] = 1; }
			for($i = 0; $i < count($checkdays); $i++) {
				$day = $checkdays[$i];
				$std = 0;
				$cur = 0;
				if(isset($std_days_assoc[$day])) $std = 1;
				if(isset($cur_days_assoc[$day])) $cur = 1;

				if($cur && $std)
					$days[] = "<span class=\"weekday-on\">$day</span>";
				else if($cur)
					$days[] = "<span class=\"weekday-temp\">$day</span>";
				else if($std)
					$days[] = "<span class=\"weekday-off\">$day</span>";
			}
			$daytext = implode(", ", $days);

			if($row["cal_type"] == "normal")
				$cal = "Regular";
			else if($row["cal_type"] == "holidays")
				$cal = "National Holidays";
			else if($row["cal_type"] == "Brandeis")
				$cal = "Brandeis";

			echo preg_replace(
				array("/__DELETE_CLASS__/",
				      "/__ID__/",
				      "/__DELETE__/",
				      "/__TIME__/",
				      "/__MESSAGE__/",
				      "/__DAYS__/",
				      "/__CAL__/"),
				array($delete_class,
				      $row["wake_id"],
				      $delete,
				      $time,
				      $row["message"],
				      $daytext,
				      $cal),
				$TEMPLATE["wake_list_item_recur"]
			);
		}
		if($delete) echo "</span>";
	}
	echo $TEMPLATE["wake_list_end"];
	if(isset($_POST["op"]) && $_POST["op"] == "Delete marked wake-up calls") echo $TEMPLATE["delete_confirm"];

	mysql_close($dbh);	
} else {
	echo $TEMPLATE["viewcalls_start_noext"];
	echo preg_replace("/__EXTENSION__/", $extension, $TEMPLATE["get_extension"]);
}

do_end();

?>
