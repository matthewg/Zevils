<?
function get_dbh() {
	$dbh = @mysql_connect("localhost", "root", "");
	if(!$dbh) return $dbh;

	if(!@mysql_select_db("finnegan", $dbh)) return "";

	return $dbh;
}
?>
