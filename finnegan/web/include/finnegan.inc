<?

$path = ".";
if(isset($cisco) && $cisco) $path = "../..";

require "$path/include/finnegan-config.inc";
require "$path/templates/global.inc";
require "$path/templates/".$page.".inc";
require "$path/include/common-funcs.inc";
if(isset($cisco) && $cisco) {
	require "$path/include/cisco-funcs.inc";
} else {
	require "$path/include/web-funcs.inc";
}

?>
