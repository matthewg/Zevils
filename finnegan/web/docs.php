<?

require "template.inc";

echo preg_replace("/__TITLE__/",
	"Finnegan: Wake-up Calls by the Brandeis University Student Union",
	$TEMPLATE["page_start"]
);

echo $TEMPLATE["docs_start"];
?>

<?
echo $TEMPLATE["docs_end"];
echo $TEMPLATE["page_end"];
?>
