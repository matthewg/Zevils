<?

require_once "wins.php";
require_once "cifs.php";

if($_REQUEST["host"]) {
	$host = $_REQUEST["host"];
	$smb = cifs_connect("minusone", $host, "129.64.99.110");
	if($smb["error"]) {
		echo "Error: " . $smb["error"] . "<br>\n";
	} else {
		echo "Success!  Shares:<br>\n";
		$shares = cifs_enum_shares($smb);
		if($smb["error"]) {
			echo "Error: " . $smb["error"] . "<br>\n";
		} else {
			echo "<ul>";
			while(list($share, $type) = each($shares)) {
				echo "<li>$share = $type";
				if($type == 0) {
					cifs_connect_share($smb);
					if($smb["error"]) {
						echo " (ERROR: " . $smb["error"] . ")";
					} else {
						
						cifs_disconnect_share($smb);
					}
				}
				echo "</li>\n";
			}
		}

		cifs_logout($smb);
	}
	@fclose($smb["sock"]);
} else {
	$host = "minusone";
}
?>

<form method="post" action="php-smb.php">
<input type="text" name="host" value="<?echo urlencode($host)?>"><input type="submit" name="submit">
</form>

