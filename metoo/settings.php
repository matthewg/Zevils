<?php

if(!defined("PHORUM_ADMIN")) return;

require_once("./mods/metoo/metoo.php");
global $PHORUM;

if(count($_POST)) {
    $mod_metoo = $PHORUM["mod_metoo"];
    
    $flags_tmp = explode(",", $_POST["metoo_flags"]);
    $flags = array();
    foreach($flags_tmp as $flag_group) {
        $flag_group_elements = explode("|", $flag_group);
        $flags[] = $flag_group_elements;
    }

    $mod_metoo["flags"] = $flags;
    if(!phorum_db_update_settings(array(
        "mod_metoo" => $mod_metoo
    ))) {
        phorum_admin_error("Updating the settings in the database failed.");
    } else {
        phorum_admin_okmsg("Settings updated");
    }
}

$flags = phorum_mod_metoo_default_flags();
if(isset($PHORUM["mod_metoo"])) {
    $flags = $PHORUM["mod_metoo"]["flags"];
}

$flag_groups = array();
foreach($flags as $flag_group) {
    $flag_groups[] = join("|", $flag_group);
}
$flags_txt = join(",", $flag_groups);

?>

<div style="font-size: xx-large; font-weight: bold">MeToo Module</div>
<div style="padding-bottom: 15px; font-size: small">
  Allows users to set admin-specified flags on posts/replies.
</div>
<?php

include_once "./include/admin/PhorumInputForm.php";
$frm = new PhorumInputForm ("", "post", "Save");
$frm->hidden("module", "modsettings");
$frm->hidden("mod", "metoo");

$row = $frm->addrow("Flags",
                    $frm->text_box("metoo_flags",
                                   $flags_txt,
                                   50)
                );
$frm->addhelp($row, "Flags", "List of flags, separated by commas.  For a group of exclusive flags, separate them by pipes.  For instance: Interesting,Informative,Off-Topic,Agree|Disagree,Good|Evil");

$frm->show();
?>

