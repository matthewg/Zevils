<?

$page = "wakes";
require "include/finnegan.inc";
page_start();

if(!$auth_ok) redirect("login.php");

if(isset($_POST["op"])) {
	$op = $_POST["op"];
	if($op == "Confirm Deletion" && isset($_POST["id"])) {
		while(list($id, $value) = each($_POST["id"])) {
			if(!preg_match('/^[0-9]+$/', $id)) unset($_POST["id"]);
		}
		$keys = implode(", ", array_keys($_POST["id"]));

		if(!mysql_query(sprintf("DELETE FROM wakes WHERE extension='%s' AND wake_id IN (%s)", $extension, $keys))) db_error();

		reset($_POST["id"]);
		while(list($id, $value) = each($_POST["id"])) {
			log_wake($id, $extension, "delete", "success");
		}
	}
}

while(list($name, $val) = each($_POST)) {
	if(preg_match("/^wake-(en|dis)able-([0-9]+)\$/", $name, $matches)) {
		if($matches[1] == "en")
			$newval = 0;
		else
			$newval = 1;
		if(!mysql_query("UPDATE wakes SET disabled=$newval WHERE extension='$extension' AND wake_id=$matches[2]")) db_error();
	}
}
reset($_POST);

$result = get_wakes();

$count = mysql_num_rows($result);
echo preg_replace("/__COUNT__/", $count, $TEMPLATE["wakes"]["list_start"]);
while($count && ($row = mysql_fetch_assoc($result))) {
	$button = "";
	$delete = "";
	$class = "";

	if($row["disabled"]) {
		$button = preg_replace("/__ID__/", $row["wake_id"], $TEMPLATE["wakes"]["list_item_enable_button"]);
		$class = "wake-disabled";
	} else {
		$button = preg_replace("/__ID__/", $row["wake_id"], $TEMPLATE["wakes"]["list_item_disable_button"]);
		$class = "wake-enabled";
	}

	if(isset($_POST["op"]) && $_POST["op"] == "Delete marked wake-up calls" && isset($_POST["id"][$row["wake_id"]])) {
		$delete = "checked";
		$class = "wake-deleted";
	}

	$time_array = time_to_user($row["time"]);
	if(!$time_array[0]) {
		echo preg_replace("/__DATE__/", $row["time"], $TEMPLATE["global"]["date_error"]);
		page_end();
	}
	$time = "$time_array[0] $time_array[1]";

	if($row["date"]) {
		$button = ""; # Doesn't make sense to disable one-time wakes!
		$date = date_to_user($row["date"]);
		if(!$date) {
			echo preg_replace("/__DATE__/", $row["date"], $TEMPLATE["global"]["date_error"]);
			page_end();
		}

		echo preg_replace(
			array("/__CLASS__/",
			      "/__ID__/",
			      "/__DELETE__/",
			      "/__TIME__/",
			      "/__MESSAGE__/",
			      "/__DATE__/",
			      "/__BUTTON__/"),
			array($class,
			      $row["wake_id"],
			      $delete,
			      $time,
			      $row["message"],
			      $date,
			      $button),
			$TEMPLATE["wakes"]["list_item_once"]
		);
	} else {
		$days = explode(",", $row["weekdays"]);
		for($i = 0; $i < count($days); $i++) $days[$i] = ucfirst($days[$i]);
		$daytext = implode(", ", $days);

		if($row["cal_type"] == "normal")
			$cal = "Regular";
		else if($row["cal_type"] == "holidays")
			$cal = "National Holidays";
		else if($row["cal_type"] == "Brandeis")
			$cal = "Brandeis";

		echo preg_replace(
			array("/__CLASS__/",
			      "/__ID__/",
			      "/__DELETE__/",
			      "/__TIME__/",
			      "/__MESSAGE__/",
			      "/__DAYS__/",
			      "/__CAL__/",
			      "/__BUTTON__/"),
			array($class,
			      $row["wake_id"],
			      $delete,
			      $time,
			      $row["message"],
			      $daytext,
			      $cal,
			      $button),
			$TEMPLATE["wakes"]["list_item_recur"]
		);
	}
}
echo $TEMPLATE["wakes"]["list_end"];
if(isset($_POST["op"]) && $_POST["op"] == "Delete marked wake-up calls") echo $TEMPLATE["wakes"]["delete_confirm"];

page_end();

?>
