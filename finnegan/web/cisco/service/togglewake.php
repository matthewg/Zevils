<?

$cisco = 1;
require "../../include/finnegan.inc";

if($_REQUEST["id"]) {
	$id = preg_replace("/[^0-9]/", "", $_REQUEST["id"]);
	$wake = @mysql_query("UPDATE wakes SET disabled = !disabled WHERE extension='$extension' AND wake_id=$id");
	if(!$wake) db_error();

	if(!mysql_affected_rows()) {
		cisco_error("Invalid Alarm", "Please select a valid alarm.");
	} else {
		cisco_message("Alarm Modified", "Alarm modified.", $FinneganCiscoConfig->url_base."/service/wakes.php");
	}
} else {
	cisco_error("Select Alarm", "Please select an alarm to modify.", $FinneganCiscoConfig->url_base."/service/wakes.php");
}

?>
