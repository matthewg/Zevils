package ScandanavianCase;
        require Exporter;
        @ISA = qw(Exporter);
        @EXPORT_OK = qw(lc uc);

	sub lc(;$) {
	        my $arg = shift || $_;
	        $arg =~ tr/[]\\/{}|/;   
	        CORE::lc($arg);
	}

	sub uc(;$) {
	        my $arg = shift || $_;
	        $arg =~ tr/{}|/[]\\/;  
	        CORE::uc($arg);
	}
