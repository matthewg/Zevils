<?

require "db-connect.inc";
require "template.inc";

function db_error() {
	echo preg_replace("/__ERROR__/", "Couldn't connect: " . mysql_error(), $TEMPLATE["db_error"]);
	do_end();
}

function extension_ok($extension) {
	if(preg_match('/^[69][0-9]{4}$/', $extension))
		return 1;
	else {
		echo $TEMPLATE["extension_invalid"];
		return 0;
	}
}

function pin_ok($extension, $pin) {
	if(!extension_ok($extension)) return 0;
	if(!preg_match('/^[0-9]{0,4}$/', $pin)) {
		echo $TEMPLATE["pin_invalid"];
		return 0;
	} else {
		$result = mysql_query(sprintf("SELECT pin FROM prefs WHERE extension='%s'", $extension));
		if(!$result) db_error();

		$row = mysql_fetch_array($result, MYSQL_NUM);
		if(!$row || !$row[0]) {
			if($pin) {
				echo $TEMPLATE["pin_empty"];
				return 0;
			} else {
				return 1;
			}
		} else {
			$goodpin = $row[0];
			if($pin != $goodpin) {
				echo $TEMPLATE["pin_error"];
				return 0;
			} else {
				return 1;
			}
		}
	}
}

// 22:00:04 -> 10:00 PM
function time_to_user($sql_time) {
	if(!preg_match('/^(\d\d):(\d\d):\d\d$/', $sql_time, $matches)) return "";
	$hours = $matches[1];
	$minutes = $matches[2];
	if($hours == 0) {
		return "12:$minutes AM";
	} else if($hours < 12) {
		return "$hours:$minutes AM";
	} else if($hours == 12) {
		return "$hours:$minutes PM";
	} else if($hours < 24) {
		$hours -= 12;
		return "$hours:$minutes PM";
	} else if($hours == 24) { //24:00:00
		return "12:00 AM";
	} else {
		return "";
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

$months = array("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
$inv_months = array("Jan" => 1, "Feb" => 2, "Mar" => 3, "Apr" => 4, "May" => 5, "Jun" => 6, "Jul" => 7, "Aug" => 8, "Sep" => 9, "Oct" => 10, "Nov" => 11, "Dec" => 12);

// 1984-01-02 -> ("Jan", 2)
function date_to_user($sql_date) {
	global $months;
	if(!preg_match('/^\d\d\d\d-(\d\d)-(\d\d)$/', $sql_date, $matches)) return "";
	$month = 0+$matches[1];
	$day = $matches[2];
	return array($months[$month-1], $day);
}

// ("Jan", 2) -> 1984-01-02
function date_to_sql($month, $day) {
	global $inv_months;
	if(!isset($inv_months[$month])) return "";
	return "1984-" . $inv_months[$month] . "-$day";
}

function do_end() {
	global $TEMPLATE;
	echo $TEMPLATE["viewcalls_end"];
	echo $TEMPLATE["page_end"];
	exit;
}

$extension = "";
$extension_ok = 0;
if(isset($_COOKIE["finnegan-extension"])) $extension = $_COOKIE["finnegan-extension"];
if(isset($_POST["extension"])) $extension = $_POST["extension"];

$pin = "";
if(isset($_COOKIE["finnegan-pin"])) $pin = $_COOKIE["finnegan-pin"];
if(isset($_POST["pin"])) $pin = $_POST["pin"];

if($extension) {
	if(extension_ok($extension) && pin_ok($extension, $pin)) {
		$extension_ok = 1;
		setcookie("finnegan-extension", $extension, time()+60*60*24*365);

		if(isset($_POST["savepin"]) && $_POST["savepin"] == "1") {
			setcookie("finnegan-pin", $pin, time()+60*60*24*365);
		} else {
			setcookie("finnegan-pin", $pin);
		}
	}
}

echo preg_replace("/__TITLE__/",
	"Finnegan: Wake-up Calls by the Brandeis University Student Union",
	$TEMPLATE["page_start"]
);

if($extension_ok) {
	echo $TEMPLATE["viewcalls_start"];

	$dbh = get_dbh();
	if(!$dbh) db_error();

	printf('<input type="hidden" name="extension" value="%s">',
		$extension);

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
				do_end();
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
	echo preg_replace("/__FORM_PARAMETERS__/",
		'method="post" action="index.php"',
		$TEMPLATE["viewcalls_start_noext"]
	);
	echo preg_replace("/__EXTENSION__/", $extension, $TEMPLATE["get_extension"]);
}

do_end();

?>
