<?

$cisco = 1;
require "../../include/finnegan.inc";
header("Expires: -1"); //Don't add to history

if($_REQUEST["id"]) {
	$id = preg_replace("/[^0-9]/", "", $_REQUEST["id"]);
	$wake = @mysql_query("DELETE FROM wakes WHERE extension='$extension' AND wake_id=$id");
	if(!$wake) db_error();

	if(!mysql_affected_rows()) {
		cisco_error("Invalid Alarm", "Please select a valid alarm.");
	} else {
		cisco_message("Alarm Deleted", "Alarm deleted.", "wakes.php");
	}
} else {
	cisco_error("Select Alarm", "Please select an alarm to delete.");
}

?>
