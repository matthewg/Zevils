<?

$cisco = 1;
require "../../include/finnegan.inc";

?>

<CiscoIPPhoneMenu>
<Title>Wake-up Calls</Title>
<Prompt>Select an option</Prompt>

<MenuItem>
<Name>View/Edit Alarms</Name>
<URL><?echo $FinneganCiscoConfig->url_base?>/service/wakes.php</URL>
</MenuItem>

<MenuItem>
<Name>New Alarm</Name>
<URL><?echo $FinneganCiscoConfig->url_base?>/service/mkwake.php</URL>
</MenuItem>

<MenuItem>
<Name>Set PIN</Name>
<URL><?echo $FinneganCiscoConfig->url_base?>/service/setpin.php</URL>
</MenuItem>

<SoftKeyItem>
<Name>Select</Name>
<URL>SoftKey:Select</URL>
<Position>1</Position>
</SoftKeyItem>

<SoftKeyItem>
<Name>Exit</Name>
<URL>SoftKey:Exit</URL>
<Position>2</Position>
</SoftKeyItem>

<SoftKeyItem>
<Name>About</Name>
<URL><? echo $FinneganCiscoConfig->url_base ?>/service/about.php?prevurl=<?echo htmlentities(current_url())?></URL>
<Position>4</Position>
</SoftKeyItem>

</CiscoIPPhoneMenu>
