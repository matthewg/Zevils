<?

$phonepage = implode("", @file("http://".$_SERVER["REMOTE_ADDR"]."/"));
if(!$phonepage) {
	echo "Can't find extension\n";
} else if(!preg_match("!Phone DN.*?<TD>(?:<[^>]*>)*[0-9]*([6-9][0-9]{4})\\b!mi", $phonepage, $matches)) {
	echo "Can't parse extension info\n";
} else {
	$extension = $matches[1];
	echo "Got x$extension\n";
}

?>
