<?

require "db-connect.inc";
require "template.inc";
require "common-funcs.inc";

if(isset($_POST["id"])) {
	$id = $_POST["id"];
	$page = "mkwake_edit";
} else
	$page = "mkwake_new";

ob_start();
$dbh = get_dbh();
if(!$dbh) return db_error();

check_extension_pin();

echo preg_replace("/__TITLE__/",
	"Finnegan: Wake-up Calls by the Brandeis University Student Union",
	$TEMPLATE["page_start"]
);

if($extension_ok) {
	echo $TEMPLATE[$page."_start"];

	if(isset($_POST["op"])) {
		$op = $_POST["op"];
	}

	echo preg_replace(array(
			"/__TIME__/",
			"/__RECUR__/", "/__ONETIME__/",
			"/__AM__/", "/__PM__/",
			"/__MESSAGE__/",
			"/__DATE__/",
			"/__MON__/", "/__TUE__/", "/__WED__/", "/__THU__/", "/__FRI__/", "/__SAT__/", "/__SUN__/",
			"/__MON_CUR__/", "/__TUE_CUR__/", "/__WED_CUR__/", "/__THU_CUR__/", "/__FRI_CUR__/", "/__SAT_CUR__/", "/__SUN_CIR__/",
			"/__CALTYPE_BRANDEIS__/", "/__CALTYPE_HOLIDAYS__/", "/__CALTYPE_NORMAL__/",
		), array(
			"",
			"", "",
			"", "",
			"",
			"",
			"", "", "", "", "", "", "",
			"", "", "", "", "", "", "",
			"", "", ""
		), $TEMPLATE["mkwake_form"]
	);

	mysql_close($dbh);	
} else {
	echo $TEMPLATE["viewcalls_start_noext"];
	echo preg_replace("/__EXTENSION__/", $extension, $TEMPLATE["get_extension"]);
	$page = "viewcalls";
}

do_end();

?>
