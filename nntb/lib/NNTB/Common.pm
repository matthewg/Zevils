package NNTB::Common;

$VERSION = 0.01;
@ISA = qw(Exporter);
@EXPORT = qw(
	LOG_ERROR LOG_WARNING LOG_NOTICE LOG_INFO LOG_DEBUG
	ERR_NOARTICLE ERR_MUSTAUTH
);

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT);
require Exporter;

use constant LOG_ERROR => 0;
use constant LOG_WARNING => 1;
use constant LOG_NOTICE => 2;
use constant LOG_INFO => 3;
use constant LOG_DEBUG => 4;

use constant ERR_NOARTICLE => "430 No Such Article";
use constant ERR_MUSTAUTH => "480 Authorization Required";
