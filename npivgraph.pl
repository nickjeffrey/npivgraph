#!/usr/bin/perl
# npivgraph.pl
#
# Copyright 2012 Brian Smith 
#
# version 0.2 Alpha - 10/12/12
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

use strict;
use Getopt::Std;

my (%dup,@out,@lparlist,%opts,$lparline,$line,$vioc,$lpar,$fcs,$vio,$system,$hmc,%lparadp,%adpclt,$adpctlkey,%lparspf);

sub printnd{
  my $s = $_[0];
  if (! grep /\Q$s/, %dup){
    print "$s\n";
    $dup{$s} = "";
  }
}

sub showusage{
  print "\nUsage $0 -h hmcserver -m managedsystem [-l lpar] [-f fcs] [-v vioserver]\n";
  print " -h specifies hmcserver name (can also be username\@hmc) \n";
  print " -m specifies managed system name\n";
  print " [-l lpar] only graph on specific lpar and its VIO servers\n";
  print " [-f fcs]  only graph specified vio FCS adapter (i.e. - \"-f fcs2\")\n";
  print " [-f vioserver]  only graph adapters on specified vio (i.e. - \"-v vio1\")\n\n";
  print "Examples:\n";
  print "Graph all:\n";
  print "   $0 -h hscroot\@hmcserver1 -m p520\n";
  print "Graph only fcs0 VIO adapter(s):\n";
  print "   $0 -h hscroot\@hmcserver1 -m p520 -f fcs0\n";
  print "Graph only aixtest01 LPAR:\n";
  print "   $0 -h hscroot\@hmcserver1 -m p520 -l aixtest01\n";
  print "Graph only things connected to vio2:\n";
  print "   $0 -h hscroot\@hmcserver1 -m p520 -v vio2\n";
  print "Graph only things connected to vio2 on fcs0:\n";
  print "   $0 -h hscroot\@hmcserver1 -m p520 -f fcs0 -v vio2\n\n";
  exit 1;
}

getopts ("v:l:f:h:m:", \%opts );
$hmc = $opts{h};
$system = $opts{m};
$lpar = $opts{l};
$fcs = $opts{f};
$vio = $opts{v};

if ( ($hmc eq "") || ($system eq "") ){ showusage();}

@lparlist = `ssh -q -o "BatchMode yes" $hmc 'lssyscfg -m $system -r lpar -F "name,lpar_env,state" | sort'`;
if ($#lparlist == -1) {
  print "Error running command on HMC.  Verify SSH keys, HMC server name, and managed system names are correct.\n";
  exit 2;
}

print "graph npivgraph { \n";
print "rankdir=LR\n";
print "ranksep=.5\n";
print "nodesep=.4\n";

foreach $lparline (@lparlist){
  if ($lparline =~ /(\S+),(\S+),(.*)/){
    my $vios = $1;
    my $client_type = $2;
    my $client_state = $3;
    if ($client_state eq "Running" && $client_type eq "vioserver"){
      $vioc++;
      @out = `ssh -q -o "BatchMode yes" $hmc "viosvrcmd -m $system -p $vios -c 'lsmap -all -npiv -field name physloc clntname fc fcphysloc vfcclient vfcclientdrc -fmt ,'"`;
      foreach $line (@out){
        if ($line =~ /(\S+),.*-C(\d+),([^,]*),(\S+),(\S+),(\S+),.*-C(\d+)/){
          my $vfchost = $1;
          my $vioslot = $2;
          my $clntname = $3;
          my $fc = $4;
          my $fcphsloc = $5;
          my $vfcclient = $6;
          my $cslot = $7;
          if (($fcs) && ($fcs ne $fc)) {next;}
          if (($lpar) && ($lpar ne $clntname)) {next;}
          if (($vio) && ($vio ne $vios)) {next;}
          $adpctlkey = "${vios}.${fc}";
          @{$adpclt{$adpctlkey}}[0]++;
          @{$adpclt{$adpctlkey}}[1] = "VIO Physical HBA\\n$fc\\n$fcphsloc";
          $lparadp{$clntname}++;
          if ((@{$lparspf{$clntname}}[0]) && (@{$lparspf{$clntname}}[0] ne $vios)) {@{$lparspf{$clntname}}[1] = 1;} 
          @{$lparspf{$clntname}}[0] = $vios;

          if ($vioc % 2 ne 0) {
            printnd("\"${vios}\" -- \"${vios}.${fc}\"");
            printnd("\"${vios}.${fc}\" -- \"${vios}.${vfchost}\"");
            printnd("\"${vios}.${vfchost}\" -- \"${clntname}.${cslot}\"");
            printnd("\"${clntname}.${cslot}\" -- \"${clntname}\"");
          }else{
            printnd("\"${clntname}\" -- \"${clntname}.${cslot}\"");
            printnd("\"${clntname}.${cslot}\" -- \"${vios}.${vfchost}\"");
            printnd("\"${vios}.${vfchost}\" -- \"${vios}.${fc}\"");
            printnd("\"${vios}.${fc}\" -- \"${vios}\"");
          }
          printnd("\"${vios}\" [shape=box, label=\"${vios}\\nVIO\", fillcolor=\"#87CEEB\",style=filled,fontsize=9]");
          printnd("\"${vios}.${vfchost}\" [shape=box, label=\"Virt. Fiber Srv Adp.\\nVIO Slot $vioslot\\n$vfchost\",fillcolor=\"#87CEEB\",style=filled,fontsize=9]");
          printnd("\"${clntname}.${cslot}\" [shape=box, label=\"Virt. Client Adp.\\nClient Slot $cslot\\nClient Device: $vfcclient\",fillcolor=\"#90EE90\",style=filled,fontsize=9]");
        }
      }
    }
  }
}

my $key;
foreach $key (keys %lparadp){
  if (@{$lparspf{$key}}[1] == 1 || ($vio)){
    printnd("\"${key}\" [shape=box, label=\"${key}\\n$lparadp{$key} Adpapters\\nLPAR\", fillcolor=\"#87CEEB\",style=filled,fontsize=9]");
  }else{
    printnd("\"${key}\" [shape=box, label=\"${key}\\n$lparadp{$key} Adpapters\\nLPAR\\nWarning Single VIO\", fillcolor=\"#FF0000\",style=filled,fontsize=9]");
  }
}

foreach $key (keys %adpclt){
  if ($lpar){
    printnd("\"$key\" [shape=box, label=\"@{$adpclt{$key}}[1]\",fillcolor=\"#90EE90\",style=filled,fontsize=9]");
  }else{
    printnd("\"$key\" [shape=box, label=\"@{$adpclt{$key}}[1]\\n@{$adpclt{$key}}[0] Virt. adapters\",fillcolor=\"#90EE90\",style=filled,fontsize=9]");
  }
}

print "labelloc=\"t\"\n";
print "label=\"npivgraph by Brian Smith\"\n";
print "}\n";
