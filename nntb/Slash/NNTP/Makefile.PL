use ExtUtils::MakeMaker;
use DBIx::Password;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Slash::NNTP',
    'VERSION_FROM' => 'NNTP.pm', # finds $VERSION
    'PM'	=> { 'NNTP.pm' => '$(INST_LIBDIR)/NNTP.pm' },
);
