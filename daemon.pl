#!/usr/bin/perl -w
##############################################################################

use strict;
use POSIX 'setsid';

sub daemonize {
   chdir '/'               or die "Can't chdir to /: $!";
   open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
   defined(my $pid = fork) or die "Can't fork: $!";
   if ($pid){
		print  "$pid\n";
	    exit 0;
	}
   setsid                  or die "Can't start a new session: $!";
   open STDOUT, '>/dev/null'
						   or die "Can't write to /dev/null: $!";
   open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";
}

&daemonize(); 
exec(@ARGV);
