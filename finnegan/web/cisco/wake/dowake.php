<?

$cisco = 1;
require "../../include/finnegan.inc";
header("Refresh: 900; url=SoftKey:Exit");

$id = preg_replace("/[^0-9]/", "", $_REQUEST["id"]);
$date = $_REQUEST["date"] ? 1 : 0;

?>

<CiscoIPPhoneText>
<Title>Your Wake-up Call</Title>
<Text>Wake up!</Text>
<SoftKeyItem>
<Name>OK</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/wake/ok.php?id=<?echo $id ?>&amp;date=<?echo $date ?></URL>
</SoftKeyItem>
<SoftKeyItem>
<Name>Snooze</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/wake/snooze.php?id=<?echo $id ?></URL>
</SoftKeyItem>
<SoftKeyItem>
<Name>About</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/about.php</URL>
</SoftKeyItem>
</CiscoIPPhoneText>

