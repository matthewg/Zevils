<?
require "template.inc";
echo preg_replace("/__PAGE_SCRIPT__/", $TEMPLATE["legal_script"], $TEMPLATE["page_start"]);
echo $TEMPLATE["legal_start"];
?>

<p>
Finnegan is (c)2004 <a href="http://www.zevils.com/">Matthew Sachs</a> and <a href="http://union.brandeis.edu/">the Brandeis Student Union</a>.
This system may only be used by members of the Brandeis community.  You may only create, edit, or delete a wake-up call on an extension
or phone number on which you are authorized to do so.  Creating or modifying anyone else's wake-up calls, without their express
consent, or any other unauthorized use, is strictly forbidden.  All access is logged.
</p><p>
Neither Matthew Sachs, the Brandeis University Student Union, nor Brandeis University is responsible for any misuse of this
system, or any failure in its operation.
</p><p>
All content is licensed under the <a href="COPYING.txt">GNU General Public License, version 2.0</a>.  PINs and wake-up call settings
are the private property of their owners and may not be distributed without their consent.
</p>
<?
echo $TEMPLATE["legal_end"];
echo $TEMPLATE["page_end"];
?>
