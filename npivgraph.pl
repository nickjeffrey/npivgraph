#!/usr/bin/perl
# npivgraph.pl
#
# Copyright 2012 Brian Smith 
#
# CHANGE LOG
# ---------
# 2012-10-12 bsmith 	Script created version 0.2 Alpha 
# 2024-04-12 njeffrey 	significant refactoring, add error checks


# LICENSE
# -------
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



use strict;   					#enforce good coding practices
use Getopt::Long;                                               #allow --long-switches to be used as parameters


my (%dup,@out,@lparlist,$lparline,$line,$lpar,$fcs,$vio,$system,$hmc,%lparadp,%adpclt,$adpctlkey,%lparspf);
my ($key,$verbose,$cmd,$vioserver_count,$aixlinux_count,$i5os_count,$vioserver,@vioservers);
my ($managed_system,$output_file,$graphviz_dot);
my ($opt_v,$opt_V,$opt_h,$opt_H,$opt_f,$opt,$opt_m,$opt_l);
$verbose = "no";
$output_file = "/tmp/npivgraph.txt"; 


sub printnd {
   #
   print "running subroutine printnd \n" if ($verbose eq "yes");
   #
   my $s = $_[0];
   if (! grep /\Q$s/, %dup){
      print "$s\n";
      print OUT "$s\n";
      $dup{$s} = "";
   }
}



sub show_usage {
   #
   print "running subroutine show_usage \n" if ($verbose eq "yes");
   #
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
  print "Get help:\n";
  print "   $0 -H | --help \n";
  print "Add verbosity:\n";
  print "   $0 --verbose ";
  exit 1;
}



#sub get_options {
#   getopts ("v:l:f:h:m:", \%opts );
#   $hmc = $opts{h};
#   $system = $opts{m};
#   $lpar = $opts{l};
#   $fcs = $opts{f};
#   $vio = $opts{v};
#}
 

sub get_options {
   #
   # this gets the command line parameters provided by the users
   #
   print "Running get_options subroutine \n" if ($verbose eq "yes");
   Getopt::Long::Configure('bundling');
   GetOptions(
      "H"     => \$opt_H, "help"            => \$opt_H,
      "V"     => \$opt_V, "verbose"         => \$opt_V,
      "h=s"   => \$opt_h, "hmc=s"           => \$opt_h,
      "v=s"   => \$opt_v, "vio=s"           => \$opt_v,
      "f=s"   => \$opt_f, "fcs=s"           => \$opt_f,  
      "m=s"   => \$opt_m, "managedsystem=s" => \$opt_m,  
      "l=s"   => \$opt_l, "lpar=s"          => \$opt_l,  
   );
   #
   # If the user supplied the -H or --help switch, give them some help.
   #
   if( defined( $opt_H ) ) {
      show_usage();
      exit 1;                       #exit script
   }
   #
   # If the user supplied the --verbose switch, increase output verbosity
   #
   if( defined( $opt_V ) ) {
      $verbose = "yes";
   } else {
      $verbose = "no";
   }
   #
   # If the user provided -h or --hmc parameter, set value of $hmc
   #
   if( defined( $opt_h ) ) {
      $hmc = $opt_h;
      print "   setting HMC paramter to $hmc \n" if ($verbose eq "yes");
   }
   #
   # If the user provided -v or --vio parameter, set value of $vio
   #
   if( defined( $opt_v ) ) {
      $vio = $opt_v;
      print "   setting VIO server to $vio \n" if ($verbose eq "yes");
   }
   #
   # If the user provided -m or --managedserver parameter, set value of $system
   #
   if( defined( $opt_m ) ) {
      $system = $opt_m;
      print "   setting managed system to $system \n" if ($verbose eq "yes");
   }
   #
   # If the user provided -l or --lpar parameter, set value of $lpar
   #
   if( defined( $opt_l ) ) {
      $lpar = $opt_l;
      print "   setting LPAR to $lpar \n" if ($verbose eq "yes");
   }
}                                                                      #end of subroutine




sub sanity_checks {
   #
   print "running subroutine sanity_checks \n" if ($verbose eq "yes");
   #
   # confirm user entered parameters on command line
   if ( ($hmc eq "") || ($system eq "") ){ show_usage();}
   #
   #
   # Delete the output file if it already exists
   if (-e "$output_file")  {
      unlink "$output_file";
   }                                                                            #end of if block
   if (-e "$output_file")  {
      print "ERROR: Cannnot delete existing copy of output file $output_file - please check file permissions and delete manually \n";
      exit 1;
   }                                                                            #end of if block
}



sub get_lpar_names {
   #
   print "running subroutine get_lpar_names \n" if ($verbose eq "yes");
   #
   $cmd = "ssh -q $hmc 'lssyscfg -m $system -r lpar -F \"name,lpar_env,state\" | sort'";
   print "   running command: $cmd \n" if ($verbose eq "yes");
   @lparlist = `$cmd`;
   if ($#lparlist == -1) {
      print "Error running command on HMC.  Verify SSH keys, HMC server name, and managed system names are correct.\n";
      exit 1;
   }
   print "@lparlist \n" if ($verbose eq "yes");
   #
   # confirm at least one VIOS partition exists.  If there is no VIOS partition, there can be no virtual fibre channel or virtual SCSI.
   $vioserver_count = 0;
   $aixlinux_count  = 0;
   $i5os_count      = 0; 
   foreach (@lparlist) {
      if (/,aixlinux,/) {
         $aixlinux_count++;
      }
      if (/,i5os,/) {
         $i5os_count++;
      }
      if (/(\S+),vioserver,Running/) {   #TODO- add error check for VIOS partitions in "Not Activated" state
         $vioserver_count++;
         push @vioservers,$1;   #add the name of each VIOS partition to an array
      }
   }
   print "   found $vioserver_count VIOS partitions, $aixlinux_count AIX partitions, $i5os_count iSeries partitions \n" if ($verbose eq "yes");
   if ($vioserver_count < 1) {
      print "ERROR: did not detect any VIOS partitions.  Perhaps this is a full system partition host without VIOS.  No virtual FC or virtual SCSI due to no VIOS. \n";
      print "Found $vioserver_count VIOS partitions, $aixlinux_count AIX partitions, $i5os_count iSeries partitions \n";
      print "@lparlist \n";
      exit 2;
   }
}



sub create_output_file {
   #
   print "running subroutine create_output_file \n" if ($verbose eq "yes");
   #
   open(OUT,">$output_file") or die "Cannot open output file $output_file for writing $! \n";   #open a filehandle for writing 
}



sub print_graphviz_header {
   #
   print "running subroutine print_graphviz_header \n" if ($verbose eq "yes");
   #
   print "graph npivgraph { \n";
   print "rankdir=LR\n";
   print "ranksep=.5\n";
   #
   # print to $output_file
   print OUT "nodesep=.4\n";
   print OUT "graph npivgraph { \n";
   print OUT "rankdir=LR\n";
   print OUT "ranksep=.5\n";
   print OUT "nodesep=.4\n";
}


sub get_details {
   #
   print "running subroutine get_details \n" if ($verbose eq "yes");
   #
   foreach $vioserver (@vioservers){
      $cmd = "ssh -q $hmc \"viosvrcmd -m $system -p $vioserver -c 'lsmap -all -npiv -field name physloc clntname fc fcphysloc vfcclient vfcclientdrc -fmt ,'\"";
      print "   running command: $cmd \n" if ($verbose eq "yes");
      #@out = `ssh -q $hmc "viosvrcmd -m $system -p $viosserver -c 'lsmap -all -npiv -field name physloc clntname fc fcphysloc vfcclient vfcclientdrc -fmt ,'"`;
      @out = `$cmd`;
      foreach $line (@out){
         if ($line =~ /(\S+),.*-C(\d+),([^,]*),(\S+),(\S+),(\S+),.*-C(\d+)/){
            my $vfchost   = $1;
            my $vioslot   = $2;
            my $clntname  = $3;
            my $fc        = $4;
            my $fcphsloc  = $5;
            my $vfcclient = $6;
            my $cslot     = $7;
            if (($fcs) && ($fcs ne $fc)) {next;}
            if (($lpar) && ($lpar ne $clntname)) {next;}
            if (($vio) && ($vio ne $vioserver)) {next;}
            $adpctlkey = "${vioserver}.${fc}";
            @{$adpclt{$adpctlkey}}[0]++;
            @{$adpclt{$adpctlkey}}[1] = "VIO Physical HBA\\n$fc\\n$fcphsloc";
            $lparadp{$clntname}++;
            if ((@{$lparspf{$clntname}}[0]) && (@{$lparspf{$clntname}}[0] ne $vioserver)) {@{$lparspf{$clntname}}[1] = 1;} 
            @{$lparspf{$clntname}}[0] = $vioserver;

            if ($vioserver_count % 2 ne 0) {    #confirm the number of VIOS partitions is evenly divisible by two
               printnd("\"${vioserver}\" -- \"${vioserver}.${fc}\"");
               printnd("\"${vioserver}.${fc}\" -- \"${vioserver}.${vfchost}\"");
               printnd("\"${vioserver}.${vfchost}\" -- \"${clntname}.${cslot}\"");
               printnd("\"${clntname}.${cslot}\" -- \"${clntname}\"");
            }else{
               printnd("\"${clntname}\" -- \"${clntname}.${cslot}\"");
               printnd("\"${clntname}.${cslot}\" -- \"${vioserver}.${vfchost}\"");
               printnd("\"${vioserver}.${vfchost}\" -- \"${vioserver}.${fc}\"");
               printnd("\"${vioserver}.${fc}\" -- \"${vioserver}\"");
            }
            printnd("\"${vioserver}\" [shape=box, label=\"${vioserver}\\nVIO\", fillcolor=\"#87CEEB\",style=filled,fontsize=9]");
            printnd("\"${vioserver}.${vfchost}\" [shape=box, label=\"Virt. Fiber Srv Adp.\\nVIO Slot $vioslot\\n$vfchost\",fillcolor=\"#87CEEB\",style=filled,fontsize=9]");
            printnd("\"${clntname}.${cslot}\" [shape=box, label=\"Virt. Client Adp.\\nClient Slot $cslot\\nClient Device: $vfcclient\",fillcolor=\"#90EE90\",style=filled,fontsize=9]");
         }
      }
   } 

   #print graphviz commands 
   foreach $key (keys %lparadp){
      if (@{$lparspf{$key}}[1] == 1 || ($vio)){
         printnd("\"${key}\" [shape=box, label=\"${key}\\n$lparadp{$key} Adpapters\\nLPAR\", fillcolor=\"#87CEEB\",style=filled,fontsize=9]");
      }else{
         printnd("\"${key}\" [shape=box, label=\"${key}\\n$lparadp{$key} Adpapters\\nLPAR\\nWarning Single VIO\", fillcolor=\"#FF0000\",style=filled,fontsize=9]");
      }
   }

   #print graphviz commands 
   foreach $key (keys %adpclt){
      if ($lpar){
         printnd("\"$key\" [shape=box, label=\"@{$adpclt{$key}}[1]\",fillcolor=\"#90EE90\",style=filled,fontsize=9]");
      }else{
         printnd("\"$key\" [shape=box, label=\"@{$adpclt{$key}}[1]\\n@{$adpclt{$key}}[0] Virt. adapters\",fillcolor=\"#90EE90\",style=filled,fontsize=9]");
      }
   }
}


sub print_graphviz_footer {
   #
   print "running subroutine print_graphviz_footer \n" if ($verbose eq "yes");
   #
   print "labelloc=\"t\"\n";
   print "label=\"npivgraph by Brian Smith\"\n";
   print "}\n";
   #
   print OUT "labelloc=\"t\"\n";
   print OUT "label=\"npivgraph by Brian Smith\"\n";
   print OUT "}\n";
}



sub create_image_file {
   #
   print "running subroutine create_image_file \n" if ($verbose eq "yes");
   #
   # Check to see if the the "dot" program is installed from GraphViz
   $graphviz_dot = "/bogus/dummyfile";
   $graphviz_dot = "/usr/bin/dot" if (-e "/usr/bin/dot"); 
   $graphviz_dot = "/bin/dot"     if (-e "/bin/dot"); 
   if (-e "$graphviz_dot") {
      $cmd = "cat $output_file | $graphviz_dot -T png -o npivgraph.png";
      print "Please run the following command to create a PNG image from the GraphViz data in the text file $output_file : \n";
      print "      cat $output_file | dot -T png -o npivgraph.png \n";
   } else {
      print "NOTE: Could not find the dot program, GraphViz might not be installed, \n";
      print "      unable to create PNG image file.\n";
      print "      Please copy the $output_file text file to some other machine that \n";
      print "      has GraphViz installed, then create the PNG image file with:\n"; 
      print "      cat $output_file | dot -T png -o npivgraph.png \n";
   }
}
   

# -------------- main body of script ---------------------
get_options;
sanity_checks;
get_lpar_names;
create_output_file;
print_graphviz_header;
get_details;
print_graphviz_footer;
create_image_file;

