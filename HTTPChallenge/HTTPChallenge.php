<?php

$wgExtensionCredits['other'][] = array(
                                   'name' => 'HTTPChallenge',
                                   'author' => 'Matthew Sachs',
                                   'url' => 'http://zevils.com/',
                                   'description' => 'Sends HTTP authentication challenge'
                                   );
$wgHooks['AutoAuthenticate'][] = 'fnHTTPChallenge';

function fnHTTPChallenge(&$user) {
    global $wgRequest;

    if(!$wgRequest->getVal("auth")) return true;
    
    $l = $wgRequest->getVal("l");
    $p = $wgRequest->getVal("p");
    if(!$l || !$p) return false;
    
    global $wgContLang;
    $name = $wgContLang->ucfirst($l);
    $t = Title::newFromText($name);
    if(is_null($t)) return false;

    global $wgAuth;
    $canonicalName = $wgAuth->getCanonicalName($t->getText());
    if(!User::isValidUserName($canonicalName)) return false;

    $u = User::newFromName($canonicalName);
    if(0 == $u->getID()) return false;
    if(!$u->checkPassword($p)) return false;
    $user = $u;
    $user->setCookies();
    
    return true;
}

?>
