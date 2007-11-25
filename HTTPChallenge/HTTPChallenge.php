<?php

$wgExtensionCredits['other'][] = array(
                                   'name' => 'HTTPChallenge',
                                   'author' => 'Matthew Sachs',
                                   'url' => 'http://zevils.com/',
                                   'description' => 'Sends HTTP authentication challenge'
                                   );
$wgHooks['AutoAuthenticate'][] = 'fnHTTPChallenge';

function fnHTTPChallenge(&$user) {
    global $wgSiteName;

    wfSetupSession();

    if(!isset($_REQUEST["auth"])) return true;

    $user = $_REQUEST['u'];
    $pw = $_REQUEST['p'];
    
    global $wgContLang;
    $name = $wgContLang->ucfirst($user);
    $t = Title::newFromText($name);
    if(is_null($t)) return null;

    global $wgAuth;
    $canonicalName = $wgAuth->getCanonicalName($t->getText());
    if(!User::isValidUserName($canonicalName)) return null;

    $u = User::newFromName($canonicalName);
    if(0 == $u->getID()) return null;
    if(!$u->checkPassword($pw)) return null;
    $user = $u;
    $user->setCookies();
    
    return true;
}

?>
