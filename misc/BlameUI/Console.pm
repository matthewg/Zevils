package BlameUI::Console;

use strict;
use warnings;
use Term::Cap;
use Term::ReadKey;
use Term::ANSIColor qw(:constants);
use POSIX qw(floor);
use List::Util qw(max min);
use Carp qw(confess);

use constant KEY_LEFT => 68;
use constant KEY_RIGHT => 67;
use constant KEY_UP => 65;
use constant KEY_DOWN => 66;

sub new {
  my($class, $diffData, $getLogFn) = @_;
  $class = ref($class) || $class || __PACKAGE__;
  my $self = {
              diffData => $diffData,
              getLogFn => $getLogFn,
              };
  bless $self, $class;
  $self->setMode("mixed");
  $self;
}

sub findLine {
  my($termLines, $target, $lineTransform) = @_;

  my($lbound, $ubound) = (0, scalar(@$termLines));
  while($lbound <= $ubound) {
    my $thisLineNo = $lbound + floor(($ubound - $lbound) / 2);
    my $thisValue = $lineTransform->($termLines->[$thisLineNo]);
    if($thisValue < $target) {
      $lbound = $thisLineNo + 1;
    } elsif($thisValue > $target) {
      $ubound = $thisLineNo - 1;
    } else {
      return $thisLineNo;
    }
  }

  return $ubound;
}

sub computeBoundaries {
  my($self) = @_;

  $self->{maxFileLine} = @{$self->{termLines}} ?
    $self->{termLines}->[-1]->[0] + 1 :
    0;
  $self->{lineDigits} = $self->{maxFileLine} ?
    floor(log($self->{maxFileLine}) / log(10)) + 1 :
    1;
  $self->{displayLines} = $self->{termHeight} - 1;
  $self->{lastTermLine} = scalar(@{$self->{termLines}});
  $self->{maxStartTermLine} = max($self->{lastTermLine} - $self->{displayLines},
                                  0);
}

sub setMode {
  my($self, $mode) = @_;
  my $oldMode = $self->{mode};
  my $oldLines = $self->{termLines};
  $self->{mode} = $mode;

  if($mode eq "log") {
    $self->{startTermLine} = 0;
    $self->{diffData}->{log} = $self->{getLogFn}->()
      unless $self->{diffData}->{log};
  }
  $self->{termLines} = $self->{diffData}->{$mode};

  if($self->{startTermLine} and $oldMode ne "log") {
    my $lines = $self->{termLines};
    my $startLine = $self->{startTermLine};
    my($old_lineno, $new_lineno) = ($oldLines->[$startLine]->oldFileLine,
                                    $oldLines->[$startLine]->newFileLine);

    my $get_line_number;
    # Pick where to scroll to by trying to keep either the old or
    # new line number constant.  Use whichever of the two there are
    # more of to maximize precision.
    if($old_lineno and $new_lineno and $old_lineno > $new_lineno) {
      $get_line_number = sub { shift->oldFileLine; };
    } else {
      $get_line_number = sub { shift->newFileLine; };
    }

    if($lines->[$startLine]) {
      my $target = $get_line_number->($oldLines->[$startLine]);
      $self->{startTermLine} = findLine($lines,
                                        $target,
                                        $get_line_number);
    } else {
      $self->{startTermLine} = 0;
    }
  }

  $self->computeBoundaries();
}

sub updateGeometry {
  my($self) = @_;
  my($termWidth, $termHeight) = GetTerminalSize();
  $self->{termWidth} = $termWidth;
  $self->{termHeight} = $termHeight;
  $self->computeBoundaries();
}

sub scroll {
  my($self, $distance) = @_;
  $self->{startTermLine} += $distance;
  if($distance < 0) {
    $self->{startTermLine} = max($self->{startTermLine},
                                 0);
  } else {
    $self->{startTermLine} = min($self->{startTermLine},
                                 $self->{maxStartTermLine});
  }
}

sub showDiff {
  my($self, $scrollToFileLine) = @_;

  local $SIG{WINCH} = sub {
    $self->updateGeometry();
  };
  $SIG{WINCH}->();

  my $terminal = Term::Cap->Tgetent();
  $self->{startTermLine} = 0;
  if($scrollToFileLine) {
    $self->{startTermLine} = $self->findLine(
                                             $self->{lines},
                                             $scrollToFileLine,
                                             sub { shift->oldFileLine(); }
                                            );
  }

  ReadMode(4);
  my($lastSearch, $searchMode);
  while(1) {
    $terminal->Tputs("cl", 1, *STDOUT);
    my $endTermLine = $self->{startTermLine} + $self->{displayLines};

    my $searchFound = 0;
    while(!$searchFound) {
      $searchFound = 1 unless $searchMode;

      for(my $termLine = 0; $termLine < $self->{displayLines}; $termLine++) {
        my $fileLineNo = $termLine + $self->{startTermLine};
        my $line = $self->{termLines}->[$fileLineNo];
        last unless $line;
        my $lineText = $line->lineText;
        if($lineText =~ /^\@\@/) {
          print BOLD, "...\n", RESET;
        } else {
          my $lineLength = length($lineText);
          $lineLength += $self->{lineDigits} + 1 unless $self->{mode} eq "log";
          $termLine += floor($lineLength/$self->{termWidth});

          printf "%s%$self->{lineDigits}d ", RED, $line->oldFileLine
            unless $self->{mode} eq "log";
          if($lastSearch and
             $lineText =~ s/($lastSearch)/REVERSE . $1 . RESET/ge
          ) {
            $searchFound = 1;
          }
          if($lineText =~ /^-/) {
            print "$lineText\n", RESET;
          } elsif($lineText =~ /^\+/) {
            print GREEN, "$lineText\n", RESET;
          } else {
            print RESET, "$lineText\n";
          }
        }
      }

      if($searchMode and !$searchFound) {
        if($searchMode eq "?") {
          $self->scroll(-$self->{displayLines});
        } else {
          $self->scroll($self->{displayLines});
        }
      }
    }

    print
      REVERSE,
      "== [$self->{mode}] $self->{startTermLine}-$endTermLine/$self->{lastTermLine} ==",
      RESET;

    my $key = ReadKey(0);
    undef $searchMode;
    if($key eq " ") {
      $self->scroll($self->{displayLines});
    } elsif(ord($key) == KEY_DOWN) {
      $self->scroll(1);
    } elsif($key eq "b") {
      $self->scroll(-$self->{displayLines});
    } elsif(ord($key) == KEY_UP) {
      $self->scroll(-1);
    } elsif($key eq "q") {
      print "\n";
      last;
    } elsif($key eq "o") {
      $self->setMode("old");
    } elsif($key eq "n") {
      $self->setMode("new");
    } elsif($key eq "m") {
      $self->setMode("mixed");
    } elsif($key eq "/" or $key eq "?") {
      $searchMode = $key;

      ReadMode(0);
      ReadMode(1);
      $terminal->Tputs("cr", 1, *STDOUT);
      $terminal->Tputs("ce", 1, *STDOUT);
      print $key;

      chomp(my $search = ReadLine(0));
      if(!$search and $lastSearch) {
        $search = $lastSearch;

        if($key eq "/") {
          $self->scroll($self->{displayLines});
        } else {
          $self->scroll(-$self->{displayLines});
        }
      }
      $lastSearch = $search;

      ReadMode(0);
      ReadMode(4);
    } elsif($key eq "l") {
      $self->setMode("log");
    } elsif($key eq "h") {
      $terminal->Tputs("cl", 1, *STDOUT);
      print BOLD, "Summary of commands:\n", RESET;
      print <<EOF;
   SPACE, b: Page down, up
   Down arrow, Up arrow: Line down, up
   /, ?: Search forwards, backwards
   l: Show commit log message
   o, n, m: Only show lines in old version, new version, both
   q: Quit

Press any key to return to pager...
EOF
      ReadKey(0);
    }
  }

  ReadMode(0);
}

1;
