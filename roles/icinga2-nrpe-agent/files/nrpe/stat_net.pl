#!/usr/bin/perl -w

################################################
#
# Checks the net-stat (only for status).
#   - warning state only for to much percent of errs or drop packages
#   - unknown is for unknown device
#
# Thomas Sesselmann <t.sesselmann@dkfz.de> 2010
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
# Changelog:
# v0.9  2010.10.22 (ts)
#
####


my %ERRORS=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3,'DEPENDENT'=>4);
my $warn = "10";
my $proc_net_file = "/proc/net/dev";
my %devices = ();


&get_params(@ARGV);
&test_net();


#####################################################

sub test_net() {
  
  my $return_txt='';
  my $perfdata='';
  my $status = 'OK';

  open FILE,"<$proc_net_file";
  while(<FILE>) {
    chomp $_;
    if ($_ =~ /^\s*(\w+):(.*)$/){
      my $key = lc $1;
      if(( exists $devices{all} )or( exists $devices{$key} )) {
        $devices{$key}=$2;
      }
    }
  }
  close FILE;

  foreach my $k ( sort keys %devices ) {
    if ( $k eq "all" ) { next; }
    
    if ( $devices{$k} eq "0" ) { 
      $status = 'UNKNOWN'; 
      if ( $return_txt ne "" ) { $return_txt .= ", " }
      $return_txt .= "$k=(-/-)";
      next; 
    }

    my @val = split " ",$devices{$k};
    my $rx = $val[0];
    my $tx = $val[8];

    $perfdata .= "${k}_in=${rx}c; "; #In Bytes (Counter)
    $perfdata .= "${k}_out=${tx}c; "; #Out Bytes (Counter)

    ## calculate dops and errors to percent
    if ( ( ($val[2]+$val[3]) * 100   > $warn * $rx ) or 
         ( ($val[10]+$val[11]) * 100 > $warn * $tx ) ) {
       if ( $ERRORS{$status} < $ERRORS{'WARNING'} ) { $status ='WARNING'; }
    }

    my $rx_unit = "B";
    if ( $rx > 1024 * 4 ) { $rx /= 1024; $rx_unix="kB"; }
    if ( $rx > 1024 * 4 ) { $rx /= 1024; $rx_unix="MB"; }
    if ( $rx > 1024 * 4 ) { $rx /= 1024; $rx_unix="GB"; }
    if ( $rx > 1024 * 4 ) { $rx /= 1024; $rx_unix="TB"; }

    my $tx_unit = "B";
    if ( $tx > 1024 * 4 ) { $tx /= 1024; $tx_unix="kB"; }
    if ( $tx > 1024 * 4 ) { $tx /= 1024; $tx_unix="MB"; }
    if ( $tx > 1024 * 4 ) { $tx /= 1024; $tx_unix="GB"; }
    if ( $tx > 1024 * 4 ) { $tx /= 1024; $tx_unix="TB"; }

    if ( $return_txt ne "" ) { $return_txt .= ", " }
    $return_txt .= sprintf "$k=(%.1f$rx_unit/%.1f$tx_unit)",$rx,$tx;

  }

  $return_txt = "NET $status - (Rx/Tx) $return_txt|$perfdata\n";
  &print_exit($return_txt,$ERRORS{$status});
}



sub get_params() {

  # get params
  my $test = '';
  foreach $key (@_){
    if($test eq '') { $test = $key; next; }
    if($test eq '-w') { $warn = $key; $test = ''; next; }
    if($test =~ /^-/) { &print_usage(); }
    $devices{$key}=0;
  }
  if($test ne '') { 
    $devices{$test}=0;
  }
  if( keys %devices == 0 ) { $devices{all}=0; }
  if( $warn =~ /^(\d+)%?$/ ) { 
    $warn = $1; 
  } else { 
    &print_usage;
  }
}



sub print_usage() {
  print "Usage: $0 [-w <warn-level in percent>] [devices]*\n";
  exit $ERRORS{'UNKNOWN'};
}



sub print_exit() {
  my $msg = shift;
  my $return_code = shift;

  print "$msg";
  exit $return_code;
}




__END__



