<?

$page = "index";
require "include/finnegan.inc";
page_start();

if(try_auth()) {
	$menu = $TEMPLATE["index"]["anonymous_menu"];
	$authenticated = "";
} else {
	$menu = $TEMPLATE["index"]["authenticated_menu"];
	$authenticated = preg_replace("/__EXTENSION__/", $extension, $TEMPLATE["index"]["authenticated"]);
}

echo preg_replace(array("/__AUTHENTICATED__/", "/__MENU__/"), array($authenticated, $menu), $TEMPLATE["index"]["body"]);

page_end();

?>
