<?
eval(implode('', file('../src/db-info.inc')));

function get_dbh() {
	$dbh = @mysql_connect($db_host, $db_user, $db_pass);
	if(!$dbh) return $dbh;

	if(!@mysql_select_db($db_database, $dbh)) return "";

	return $dbh;
}
?>
