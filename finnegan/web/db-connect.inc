<?
function get_dbh() {
	eval(implode('', file('../src/db-info.inc')));
	$dbh = @mysql_connect($db_host, $db_user, $db_pass);
	if(!$dbh) return $dbh;

	if(!@mysql_select_db($db_database, $dbh)) return "";

	return $dbh;
}
?>
