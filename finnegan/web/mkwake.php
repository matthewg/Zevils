<?

require "db-connect.inc";
require "template.inc";
require "common-funcs.inc";

if(isset($_POST["id"]))
	$page = "mkwake_edit";
else
	$page = "mkwake_new";

ob_start();
$dbh = get_dbh();

check_extension_pin();

echo preg_replace("/__TITLE__/",
	"Finnegan: Wake-up Calls by the Brandeis University Student Union",
	$TEMPLATE["page_start"]
);

if($extension_ok) {
	echo $TEMPLATE[$page."_start"];

	if(!$dbh) db_error();


	if(isset($_POST["op"])) {
		$op = $_POST["op"];
		if($op == "create") {
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
		}
	}


	$result = mysql_query("SELECT wake_id, time, message, date, std_weekdays, cur_weekdays, cal_type FROM wakes WHERE extension='$extension' ORDER BY time");
	if(!$result) db_error();

	$count = mysql_num_rows($result);
	echo preg_replace("/__COUNT__/", $count, $TEMPLATE["wake_list_start"]);
	while($count && ($row = mysql_fetch_assoc($result))) {
		$delete = "";
		if(isset($_POST["op"]) && $_POST["op"] == "Delete marked wake-up calls" && isset($_POST["id"][$row["wake_id"]])) {
			$delete = "SELECTED";
			echo '<span class="wake-delete">';
		}
		if($row["date"]) {
			$date = date_to_user($row["date"]);
			if(!$date) {
				echo preg_replace("/__DATE__/", $row["date"], $TEMPLATE["date_error"]);
				do_end($extension_ok);
			}
			echo preg_replace(
				array("/__ID__/",
				      "/__DELETE__/",
				      "/__TIME__/",
				      "/__MESSAGE__/",
				      "/__DATE__/"),
				array($row["wake_id"],
				      $delete,
				      $row["time"],
				      $row["message"],
				      "$date[0] $date[1]"),
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
				array("/__ID__/",
				      "/__DELETE__/",
				      "/__TIME__/",
				      "/__MESSAGE__/",
				      "/__DAYS__/",
				      "/__CAL__/"),
				array($row["wake_id"],
				      $delete,
				      $row["time"],
				      $row["message"],
				      $daytext,
				      $cal),
				$TEMPLATE["wake_list_item_recur"]
			);
		}
		if($delete) echo "</span>";
	}
	echo $TEMPLATE["wake_list_end"];

	mysql_close($dbh);	
} else {
	echo $TEMPLATE["viewcalls_start_noext"];
	echo preg_replace("/__EXTENSION__/", $extension, $TEMPLATE["get_extension"]);
	$page = "viewcalls";
}

do_end();

?>