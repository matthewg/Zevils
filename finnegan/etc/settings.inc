# This evil file works with both Perl and PHP.
# PHP replaces 'hash(' with 'array(' and '^$' with 'var $'.

#__PERLONLY_START__
package Finnegan::Config;
no strict;

sub array { return [@_]; }
sub hash { return {@_}; }
#__PERLONLY_END__
#__PHPONLY_START__
class FinneganConfig {
#__PHPONLY_END__


# Miscellaneous settings
$testmode = 1;
$nocalls = 1;
$emergency_contacts = array(); # Email these people if there's a problem with the daemon
$forbidden_extensions = array("62000", "62222", "63000", "63333", "65000");

# Security settings
$pin_regex = '^[0-9]{1,4}$';

# Phone settings
$phonelines = array("usb/ttyACM0");
$extension_regex = '^[69][0-9]{4}$';
$max_wake_duration = 120; # Maximum length of a wake-up call
$max_forgot_pin_duration = 60; # Maximum length of a 'Forgot PIN' call
$max_snooze_count = 4; # How many times can snooze be activated for a single instance of a wake-up call?
$snooze_interval = 540; # Length of snooze delay, in settings

# Database settings - if you have a sensitive password in here, watch the permissions on this file
$db = hash(
	"host" => "localhost",
	"user" => "root",
	"password" => "",
	"database" => "finnegan"
);

# Wake-up messages
$messages = array(
	hash(
		"id" => 1,
		"message" => "\"This is your wake-up call.\"",
		"mp3" => "finnegan-standard.mp3",
		"author" => "<a href=\"http://www.zevils.com/\">Matthew Sachs</a>"
	),
	hash(
		"id" => 2,
		"message" => "\"WAKE UP!!  WAKE UP!!\"",
		"mp3" => "finnegan-shout.mp3",
		"author" => "<a href=\"http://www.zevils.com/\">Matthew Sachs</a>"
	),
	hash(
		"id" => 3,
		"message" => "Musical Medley",
		"mp3" => "finnegan-medley.mp3",
		"author" => "<a href=\"http://people.brandeis.edu/~natb/\">Nat Budin</a>"
	),
	hash(
		"id" => 4,
		"message" => "\"Up and at 'em, Atom Ant.\"",
		"mp3" => "finnegan-atomant.mp3",
		"author" => "Randi Sachs"
	),
	hash(
		"id" => 5,
		"message" => "\"Wake up, wake up you sleepy-head.\"",
		"mp3" => "finnegan-sleepyhead.mp3",
		"author" => "Randi Sachs"
	),
	hash(
		"id" => 6,
		"message" => "\"Good morning.  Destruction of the planet will commence in approximately five minutes.\"",
		"mp3" => "finnegan-destruction.mp3",
		"author" => "<a href=\"http://people.brandeis.edu/~natb/\">Nat Budin</a>"
	)
);


#__PHPONLY_START__
}
#__PHPONLY_END__
