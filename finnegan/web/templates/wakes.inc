<?

$TEMPLATE["wakes"] = array(
	"title" => "Alarms",
	"start" => <<<END
<form method="post" action="wakes.php">
END
,

	"script" => "",
	"head" => "",
	"end" => "</form>",

	"list_start" => <<<END
<p class="status">
Hint: When Finnegan calls you to wake you up, hit a button
on your phone's keypad (after picking up the phone) 
to let it know that you're awake.  Otherwise, it will act
as if you've hit a 'snooze button' and call you back in nine minutes.
See <a href="docs.php#3">the Finnegan documentation</a> for details.
</p><p>
Your current wake-up calls are listed below.  To add a wake-up call,
<a href="mkwake.php">click here</a>.  To edit a wake-up call, click
the link marked 'Edit' in the row for that wake-up call.  To
delete wake-up calls, check the box in the row for each wake-up call
you'd like to delete, and then click the button mark 'Delete marked wake-up calls'
below.
</p>
<table rules="cols">
<thead><tr><th></th><th></th><th>Time</th><th>Date (mm/dd)/Days</th><th>Calendar Type</th></tr></thead>
<tbody>
END
,

	"list_item_once" => <<<END
<tr __DELETE_CLASS__>
	<td><input type="checkbox" name="id[__ID__]" value="1" __DELETE__ /></td>
	<td><a href="mkwake.php?id=__ID__">Edit</a></td>
	<td>__TIME__</td>
	<td>__DATE__</td>
	<td></td>
</tr>
END
,

	"list_item_recur" => <<<END
<tr __DELETE_CLASS__>
	<td width="5%"><input type="checkbox" name="id[__ID__]" value="1" __DELETE__ /></td>
	<td width="15%"><a href="mkwake.php?id=__ID__">Edit</a></td>
	<td width="20%">__TIME__</td>
	<td width="35%">__DAYS__</td>
	<td width="25%">__CAL__</td>
</tr>
END
,

	"list_end" => <<<END
</tbody>
</table>
<p><input type="submit" name="op" value="Delete marked wake-up calls" /></p>
END
,

	"delete_confirm" => <<<END
<p class="error">
Are you sure you want to delete the selected wake-up calls?<br />
<input type="submit" name="op" value="Confirm Deletion" />
</p>
END

);

?>
