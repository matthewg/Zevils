<?

$cisco = 1;
require "../../include/finnegan.inc";

$id = $_REQUEST["id"];

$result = mysql_query("UPDATE wakes SET snooze_count=snooze_count+1, next_trigger=NOW() + INTERVAL 9 MINUTE WHERE extension='$extension' AND wake_id='$id'");
if(mysql_affected_rows() != 1) cisco_error("Alarm Not Found", "Alarm $id was not found.");
log_wake($id, $extension, "activate", "success", "snooze");

header("Refresh: 0; url=SoftKey:Exit");
?>

<CiscoIPPhoneText>
<Title>Snooze OK</Title>
<Text>Snooze OK</Text>
</CiscoIPPhoneText>

