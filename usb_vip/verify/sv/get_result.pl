#!/usr/bin/perl

use strict;
use warnings;

my $log_dir;
my $log_file;
my @all_log_file;
my @file_cntnt;
my $row_txt;
my $rslt_str;
# Start
$log_dir = $ARGV[0];

# Get the log file
@all_log_file = `find $log_dir | grep .log\$`;

foreach $log_file (@all_log_file){
    my $rpt_log_file = $log_file;
    chomp ($rpt_log_file);
    #print $log_file;
    # Open log file
    open (INFILE, "<$log_file") or die "Can't open file $log_file";
    @file_cntnt = <INFILE>;
    close (INFILE);
    #foreach $row_txt (@file_cntnt) {
    #    print $row_txt;
    #}
    my $rslt = grep (/TEST PASSED/, @file_cntnt);
    if ($rslt) {
        $rslt_str = "PASS";
    }
    else {
        $rslt_str = "FAIL<<<<<";
    }
    $rpt_log_file =~ s/$log_dir//;
    printf "%-70s    %s", $rpt_log_file, "$rslt_str\n";
} 
