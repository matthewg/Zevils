<?

$cisco = 1;
require "../../include/finnegan.inc";

$prompt = isset($_REQUEST["prompt"]) ? $_REQUEST["prompt"] : "time";

if($prompt == "time") {
	cisco_error("Help", "Enter the time that you want the alarm to go off at.  You should use a 12-hour time, and ignore the colon, so if you wanted an alarm for 1:05 PM, you would enter '105'.");
} else if($prompt == "ampm") {
	cisco_error("Help", "Select 'AM' or 'PM'.");
} else if($prompt == "message") {
	cisco_error("Help", "Select the message you would like to hear when your alarm goes off.");
} else if($prompt == "type") {
	cisco_error("Help", "One-time alarms go off once, on a particular day.  You can set them up to a year in advance.  Recurring alarms go off every day, on days of the week that you select (e.g. 'every Monday and Wednesday'.)");
} else if($prompt == "date") {
	cisco_error("Help", "Select the date that this alarm is for.");
} else if($prompt == "weekdays") {
	cisco_error("Help", "Select which days of the week you'd like this alarm to go off on.");
} else if($prompt == "cal_type") {
	cisco_error("Help", "Alarms which use the Brandeis calendar won't go off on days when there are no classes, and will treat a Brandeis Monday as Monday.  Alarms which use the national holidays calendar won't go off on major national holidays.  Alarms which use the normal calendar will always go off.");
} else {
	cisco_error("Help", "Unknown prompt $prompt");
}

?>
