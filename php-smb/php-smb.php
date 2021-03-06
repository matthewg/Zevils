<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "DTD/xhtml1-strict.dtd">
<html>
<head><title>PHP-SMB Demo</title></head>
<body>
<?

require_once "wins.php";
require_once "cifs.php";

if($_REQUEST["host"]) {
	$inodes = array();
	$host = $_REQUEST["host"];
	$smb = cifs_connect(getenv("SERVER_NAME"), $host, $_REQUEST["wins"]);
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
					cifs_connect_share($smb, $share);
					if($smb["error"]) {
						echo " (ERROR: " . $smb["error"] . ")";
					} else {
						do_dir($smb, "\\");
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
	$wins = "";
	$host = "";
}

function do_dir($smb, $dir) {
	global $inodes;

	$files = cifs_readdir($smb, $dir);
	echo "<ul>";
	for($i = 0; $i < sizeof($files); $i++) {
		if($files[$i] == "." || $files[$i] == "..") continue;
		if(substr($dir, strlen($dir) - 1, 1) != "\\") $dir .= "\\";
		$pathinfo = cifs_pathinfo($smb, "$dir" . $files[$i]);
		if($smb["error"]) continue;

		//SMB gives 0 for inode_high when it isn't giving us a useful ino
		if($pathinfo["inode_high"] != 0 && isset($inodes["" . $pathinfo["inode_high"]])) {
			if(isset($inodes["" . $pathinfo["inode_high"]]["" . $pathinfo["inode_low"]])) {
				continue;
			} else {
				$inodes["" . $pathinfo["inode_high"]]["" . $pathinfo["inode_low"]] = 1;
			}
		} else {
			$inodes["" . $pathinfo["inode_high"]] = array();
			$inodes["" . $pathinfo["inode_high"]]["" . $pathinfo["inode_low"]] = 1;
		}
		echo "<li>" . $files[$i];
		if($pathinfo["is_directory"]) {
			echo "\\";
			do_dir($smb, $dir . $files[$i]);
		} else {
			echo " (" . $pathinfo["size"] . " bytes)";
		}
		echo "</li>\n";
	}
	echo "</ul>\n";
}

?>

<form method="post" action="php-smb.php">
Wins Server: <input type="text" name="wins" value="<?echo urlencode($wins)?>"><br />
Host to Browse: <input type="text" name="host" value="<?echo urlencode($host)?>"><input type="submit" name="submit">
</form>

</body></html>
