<?
function get_dbh() {
	$dbh = mysql_connect("localhost", "root", "")
		or die("Couldn't connect: " . mysql_error($dbh));

	if(!mysql_select_db("finnegan", $dbh)) die("Couldn't select database: " . mysql_error());

	return $dbh;
}
?>
