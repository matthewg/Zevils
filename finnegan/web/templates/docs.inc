<?

$TEMPLATE["docs"] = array(
	"title" => "Help",
	"start" => "",
	"script" => "",
	"head" => "",
	"end" => "",

	"index_start" => <<<END
<h4>Index</h4>
<ol class="faq_index">
END
,
 
	"index_entry" => <<<END
<li><a href="#__NUM__">__NAME__</></li>
END
,
 
	"index_end" => <<<END
</ol>
END
,
 
	"body_start" => "",
 
	"body_entry" => <<<END
<a name="__NUM__" /><h4>__NAME__</h4>
<p class="faq_item">
__CONTENTS__
</p>
END
,
 
	"body_end" => ""

);

?>
