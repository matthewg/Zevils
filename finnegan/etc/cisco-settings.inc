# This evil file works with both Perl and PHP.
# PHP replaces 'hash(' with 'array(' and '^$' with 'var $'.
 
#__PERLONLY_START__
package Finnegan::Config::Cisco;
no strict;
 
sub array { return [@_]; }
sub hash { return {@_}; }
#__PERLONLY_END__
#__PHPONLY_START__
class FinneganCiscoConfig {
#__PHPONLY_END__

$url_base = "http://10.10.3.20/finnegan/cisco";
$multicast_addr = "225.0.1.1";
$multicast_port_base = 20480;

#__PHPONLY_START__
}
#__PHPONLY_END__

