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
$url_base = "http://10.10.0.10/finnegan/cisco"; # Base of URLs to point phones at
$tftp_dir = "../tmp"; # Where (relative to $FINNEGAN/src if it's a relative path) to write files which need to go to the TFTP server
$tftp_prefix = ""; # Prefix which will be prepended to any TFTP file paths we send to the phones
$wake_method = "tftp"; # How we send wakeup calls to phones; valid values are "multicast", "unicast", and "tftp".

# Credentials
$post_username = "40196"; # Username for CiscoIPPhoneExecute 
$post_password = "12345"; # Password for CiscoIPPhoneExecute

# Various timeouts
$call_timeout = 900; # After this many seconds, auto-snooze
$max_wake_timeouts = 8; # After this many call timeouts, give up
$post_timeout = 60; # After this many seconds of trying to reach the phone, auto-snooze
$max_unreachable_count = 8; # After this many phone contact timeouts, give up

# (Uni|Multi)cast settings
$rtp_ip = "127.0.0.1";
$rtp_port_base = 20480;

#__PHPONLY_START__
}
#__PHPONLY_END__

