<?

$cisco = 1;
require "../../include/finnegan.inc";
header("Refresh: 900; url=SoftKey:Exit");

$id = $_REQUEST["id"];

?>

<CiscoIPPhoneText>
<Title>Your Wake-up Call</Title>
<Text>Wake up!</Text>
<SoftKeyItem>
<Name>OK</Name>
<URL>SoftKey:Exit</URL>
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

