<?

$TEMPLATE["statistics"] = array(
	"title" => "Alarms",
	"start" => "",
	"script" => "",
	"head" => "",
	"end" => "",

	"body" => <<<END
<p>
Want to see if you really have it all that bad with your 10 o'clock class, or which wakeup messages people are using?
You've come to the right place.
</p><p>
These statistics are only regenerated if they are an hour or more old.
</p>
END
,

	"stat" => "<tr><td><b>__NAME__</b></td><td>__VALUE__</td></tr>",
	"group_start" => <<<END
<h2>__TITLE__</h2>
<table rules="cols">
<thead><tr><th></th><th></th></tr></thead>
<tbody>
END
,

	"group_end" => "</tbody></table>"
);

?>
