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
sub next_num($$;$) {
	my($self, $type, $what) = @_;

	if($type eq "snum") {
		my $snum = $self->getVar("nntp_next_snum", "value");
		$self->setVar("nntp_next_snum", $snum + 1);
		return $snum;
	} elsif($type eq "section_snum") {
		my $section = $what;
		my($snum) = @{$self->sqlSelectAll("next_snum", "sections", "section=$section")};
		return undef unless $snum;
		$self->sqlUpdate("sections", {next_snum => $snum + 1}, "section=$section");
		return $snum;
	} elsif($type eq "cnum") {
		my $sid = $what;
		my($cnum) = @{$self->sqlSelectAll("next_cnum", "stories", "sid=$sid")};
		return undef unless $cnum;
		$self->sqlUpdate("stories", {next_cnum => $cnum + 1}, "sid=$sid");
		return $cnum;
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