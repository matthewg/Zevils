# This code is a part of NNTB, and is released under the GPL.
# Copyright 2002 by Matthew Sachs. See README and COPYING for
# more information, or see http://www.zevils.com/programs/nntb/.
# $Id$

package Slash::NNTP;

use strict;
use DBIx::Password;
use Slash;
use Slash::Utility;

use vars qw($VERSION);
use base 'Exporter';
use base 'Slash::DB::Utility';
use base 'Slash::DB::MySQL';

($VERSION) = ' $Revision$ ' =~ /\$Revision:\s+([^\s]+)/;

sub new {
	my($class, $user) = @_;
	my $self = {};

	my $slashdb = getCurrentDB();
	my $plugins = $slashdb->getDescriptions('plugins');
	return unless $plugins->{'NNTP'};

	bless($self, $class);
	$self->{virtual_user} = $user;
	$self->sqlConnect;

	return $self;
}

# This has a race condition - could it be made atomic?
sub nextSnum($;$) {
	my $section = shift;

	if(!$section) {
		my $snum = $self->getVar("nntp_next_snum", "value");
		$self->setVar("nntp_next_snum", $snum + 1);
		return $snum;
	} else {
		my($snum) = $self->sqlSelectAll("next_snum", "nntp_sectiondata", "section=$section");
		return undef unless $snum;
		$self->sqlUpdate("nntp_sectiondata", {next_snum => $snum + 1}, "section=$section");
		return $snum;
	}
}

sub DESTROY {
	my($self) = @_;
	$self->{_dbh}->disconnect if !$ENV{GATEWAY_INTERFACE} && $self->{_dbh};
}


1;

__END__

=head1 NAME

Slash::NNTP - NNTP splace

=head1 SYNOPSIS

	use Slash::NNTP;

=head1 DESCRIPTION

This is a part of NNTB.

=head1 AUTHOR

Matthew Sachs, matthewg@zevils.com

=head1 SEE ALSO

perl(1).

=cut
