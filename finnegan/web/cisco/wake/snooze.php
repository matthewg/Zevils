<?

$cisco = 1;
require "../../include/finnegan.inc";

$id = preg_replace("/[^0-9]/", "", $_REQUEST["id"]);

$result = mysql_query("UPDATE wakes SET next_trigger_time=NOW() + INTERVAL 9 MINUTE, this_trigger_time=NULL WHERE wake_id='$id'");
if(!$result) db_error();
if(mysql_affected_rows() != 1) cisco_error("Alarm Not Found", "Alarm $id was not found.");
mysql_query("UPDATE log_wake SET end_time=NOW, result='success', data='snooze' WHERE ISNULL(end_time) AND wake_id='$id' AND extension='$extension' AND event='activate'");

header("Refresh: 0; url=SoftKey:Exit");
?>

<CiscoIPPhoneText>
<Title>Snooze OK</Title>
<Text>Snooze OK</Text>
</CiscoIPPhoneText>

