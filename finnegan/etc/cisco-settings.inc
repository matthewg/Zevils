# This evil file works with both Perl and PHP.
# PHP replaces 'hash(' with 'array(' and '^\$' with 'var $'.
 
#__PERLONLY_START__
package Finnegan::Config::Cisco;
no strict;
 
sub array { return [@_]; }
sub hash { return {@_}; }
#__PERLONLY_END__
#__PHPONLY_START__
class FinneganCiscoConfig {
#__PHPONLY_END__

# Basic configuration
$url_base = "http://10.10.1.3/finnegan/cisco"; # Base of URLs to point phones at
$wake_method = "h323"; # How we send wakeup calls to phones; valid values are "multicast", "unicast", "h323", and "tftp".
$max_simultaneous_calls = 15; # How many simultaneous aclls should we allow?
$use_xml_service = 1; # We are using the XML service -- so don't generate PINs.

# H.323 settings
$h323_gateway = "10.10.0.51"; # IP to use for placing H.323 calls
$my_ext = ""; # Extension which calls should appear to be from -- leave blank to omit
$my_name = "Finnegan"; # How we should be identified on caller ID -- leave blank to omit
$voicemail_name = "Voicemail"; # Display name which indicates that call has been forwarded to voicemail

# TFTP settings
$tftp_dir = "../tmp"; # Where (relative to $FINNEGAN/src if it's a relative path) to write files which need to go to the TFTP server
$tftp_prefix = ""; # Prefix which will be prepended to any TFTP file paths we send to the phones

# CiscoIPPhoneExecute settings
$post_username = "40196";
$post_password = "12345";

# (Uni|Multi)cast settings
$rtp_ip = "127.0.0.1";
$rtp_port_base = 20480;

# Miscellaneous timeouts
$call_timeout = 40; # After this many seconds, auto-snooze
# See also max_wake_duration and max_snooze_count in settings.in


#__PHPONLY_START__
}
#__PHPONLY_END__

