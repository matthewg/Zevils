<?

$TEMPLATE["index"] = array(
	"title" => "Finnegan: Brandeis Wake-up Calls",
	"start" => <<<END
<h3>Welcome to Finnegan</h3>
END
,

	"script" => "",
	"head" => "",
	"end" => "",
	"anonymous_menu" => <<<END
<ul class="navigation">
<li><a href="login.php">Register or Log In</a></li>
<li><a href="docs.php">Help With Finnegan</a></li>
</ul>
END
,

	"authenticated_menu" => <<<END
<ul class="navigation">
<li><a href="wakes.php">View Alarms</a></li>
<li><a href="mkwake.php">Create New Alarm</a></li>
<li><a href="setpin.php">Change PIN or Log Out</a></li>
<li><a href="docs.php">Help With Finnegan</a></li>
</ul>
END
,

	"authenticated" => <<<END
<p class="status">You are logged in with x__EXTENSION__.</p>
END
,

	"body" => <<<END
__MENU__
__AUTHENTICATED__
<p>Welcome to Finnegan!</p>
END
);

?>
