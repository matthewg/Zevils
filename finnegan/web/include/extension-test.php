<?
# nick: 10.11.16.188
$phonepage = implode("", @file("http://10.11.16.188/"));
if(!$phonepage) {
	echo "Can't find extension\n";
} else if(!preg_match("!Phone DN.*?<TD>(?:<[^>]*>)*[0-9]*([6-9][0-9]{4})\\b!si", $phonepage, $matches)) {
	echo "Can't parse extension info\n";
} else {
	$extension = $matches[1];
	echo "Got x$extension\n";
}

?>
