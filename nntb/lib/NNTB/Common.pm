package NNTB::Common;

$VERSION = 0.01;
@ISA = qw(Exporter);
@EXPORT = qw(LOG_ERROR LOG_WARNING LOG_NOTICE LOG_INFO LOG_DEBUG);

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT);
require Exporter;

use constant LOG_ERROR => 0;
use constant LOG_WARNING => 1;
use constant LOG_NOTICE => 2;
use constant LOG_INFO => 3;
use constant LOG_DEBUG => 4;

