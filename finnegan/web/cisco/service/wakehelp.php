<?

$cisco = 1;
require "../../include/finnegan.inc";

$prompt = isset($_REQUEST["p"]) ? $_REQUEST["p"] : "time";
$prevurl = preg_replace("/!/", "&", $_REQUEST["x"]);

if($prompt == "time") {
	cisco_message("Help", "Enter the time that you want the alarm to go off at.  You should use a 12-hour time.  The next screen will let you select 'AM' or 'PM'.", $prevurl);
} else if($prompt == "ampm") {
	cisco_message("Help", "Select 'AM' or 'PM'.", $prevurl);
} else if($prompt == "message") {
	cisco_message("Help", "Select the message you would like to hear when your alarm goes off.", $prevurl);
} else if($prompt == "type") {
	cisco_message("Help", "One-time alarms go off once, on a particular day.  You can set them up to a year in advance.  Recurring alarms go off every day, on days of the week that you select (e.g. 'every Monday and Wednesday'.)", $prevurl);
} else if($prompt == "date") {
	cisco_message("Help", "Select the date that this alarm is for.  For the month, enter 1 for January, 2 for February, etc.", $prevurl);
} else if($prompt == "weekdays") {
	cisco_message("Help", "Select which days of the week you'd like this alarm to go off on, then press 'Submit'.", $prevurl);
} else if($prompt == "cal_type") {
	cisco_message("Help", "Alarms which use the Brandeis calendar won't go off on days when there are no classes, and will treat a Brandeis Monday as Monday.  Alarms which use the national holidays calendar won't go off on major national holidays.  Alarms which use the normal calendar will always go off.", $prevurl);
} else {
	cisco_message("Help", "Unknown prompt $prompt", $prevurl);
}

?>
