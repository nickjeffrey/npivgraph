#!/usr/bin/perl
# npivgraph.pl
#
# Copyright 2012 Brian Smith 
# Copyright 2024 Nick Jeffrey



# CHANGE LOG
# ---------
# 2012-10-12 bsmith 	Script created version 0.2 Alpha 
# 2024-04-10 njeffrey 	significant refactoring, add error checks
# 2024-04-11 njeffrey 	add error check to ping HMC prior to attempting SSH login
# 2024-04-11 njeffrey 	add error check to validate managed system name on HMC



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
use Getopt::Long;                               #allow --long-switches to be used as parameters


my (%dup,@out,@lparlist,$lparline,$line,$lpar,$fcs,$vio,$hmc,%lparadp,%adpclt,$adpctlkey,%lparspf);
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
  print "   $0 -h hscroot\@hmc1 -m p520\n";
  print "Graph only fcs0 VIO adapter(s):\n";
  print "   $0 -h hscroot\@hmc1 -m p520 -f fcs0\n";
  print "Graph only aixtest01 LPAR:\n";
  print "   $0 -h hscroot\@hmc1 -m p520 -l aixtest01\n";
  print "Graph only things connected to vio2:\n";
  print "   $0 -h hscroot\@hmc1 -m p520 -v vio2\n";
  print "Graph only things connected to vio2 on fcs0:\n";
  print "   $0 -h hscroot\@hmc1 -m p520 -f fcs0 -v vio2\n\n";
  print "Get a list of the managed servers connected to the HMC:\n";
  print "   $0 -h hscroot\@hmc1 \n";
  print "Get help:\n";
  print "   $0 -H | --help \n";
  print "Add verbosity:\n";
  print "   $0 --verbose ";
  exit 1;
}




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
      print "   setting HMC parameter to $hmc \n" if ($verbose eq "yes");
   }
   #
   # If the user provided -v or --vio parameter, set value of $vio
   #
   if( defined( $opt_v ) ) {
      $vio = $opt_v;
      print "   setting VIO server to $vio \n" if ($verbose eq "yes");
   }
   #
   # If the user provided -m or --managedsystem parameter, set value of $managed_system
   #
   if( defined( $opt_m ) ) {
      $managed_system = $opt_m;
      print "   setting managed system to $managed_system \n" if ($verbose eq "yes");
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
   # confirm user entered the -h or --hmc parameter on command line
   if ($hmc eq "") { show_usage();}
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



sub ping_hmc {
   #
   print "running ping_hmc subroutine \n" if ($verbose eq "yes");
   #
   # This subroutine is used to verify that a valid HMC hostname/IP was provided as a command line parameter
   #
   # The command line parameter is in the format
   #        -h username@hmc
   #        -h hmc           <---assumes current username on UNIX box will be used
   # So we may or may not need to remove username@ to get the HMC hostname/IP
   #
   my $hmc_ipaddr = "";   							#initialize variabble
   my $ping_status = "";
   if ( $hmc =~ /([a-zA-Z0-9_\.\-]+)\@([a-zA-Z0-9_\.]+)/ ) {              	#look for regex that matches username@hmc
      print "   HMC was provided as $hmc , will attempt to ping $2 \n" if ($verbose eq "yes");
      $hmc_ipaddr = $2;
   } else {
      print "   HMC was provided as $hmc , will attempt to ping $hmc \n" if ($verbose eq "yes");
      $hmc_ipaddr = $hmc;
   }
   #
   # ping remote hostname
   #
   $ping_status = "";                                                           #initialize variable
   if( ! open( PING, "ping -c 1 $hmc_ipaddr 2>&1|" ) ) {
      print "ERROR: Could not ping remote host $hmc_ipaddr  $! \n";
      exit 1;
   }
   while (<PING>) {                                                             #read a line from STDIN
      $ping_status = "failed" if ( /Name or service not known/ );             	#provided an invalid hostname on Linux
      $ping_status = "failed" if ( /NOT FOUND/ );                        	#provided an invalid hostname on AIX
      $ping_status = "failed" if ( /100% packet loss/ );                        #look for timeout message for UNIX ping
      $ping_status = "failed" if ( /100% loss/ );                               #look for timeout message for Windows ping
   }                                                                            #end of while loop
   close PING;                                                                  #close filehandle
   if ( $ping_status eq "failed" ) {                                            #check for flag value
      print "ERROR: no ping reply from remote host $hmc_ipaddr  \n";
      exit 1;
   }                                                                            #end of if block
}



sub ssh_to_hmc {
   #
   print "running ssh_to_hmc subroutine \n" if ($verbose eq "yes");
   #
   # This subroutine is used to verify that we can successfully login to the HMC.
   #
   $cmd = "ssh $hmc lshmc -v";                 #define command to be run
   print "   running $cmd \n" if ($verbose eq "yes");
   open(SSH,"$cmd |") or die "$!\n";
   while (<SSH>) {
      if (/Hardware Management Console/) {
         print "   confirmed successful SSH login to $hmc \n" if ($verbose eq "yes");
      }
      unless ( /[a-zA-Z0-9\"\*]+/ ) {                           #look for some output to confirm the SSH login worked
         print "ERROR: Could not make an SSH connection to $hmc  -  please confirm remote hostname/IP is correct and you are using the correct login credentials. \n";
         exit 1;
      }                                                         #end of if block
   }                                                            #end of while loop
   close SSH;                                                   #close filehandle
}                                                               #end of subroutine



sub detect_managed_system {
   #
   print "running detect_managed_system subroutine \n" if ($verbose eq "yes");
   #
   # This subroutine will only run if the user did not specific the $managed_system as a command line parameter
   #
   unless (defined($managed_system)) {
      print "ERROR: managed system was not provided as a command line parameter.  Please use this syntax: \n";
      print "       $0 -h hscroot\@hmc1 -m name_of_managed_system \n";
      print " \n";
      print "HINT: these are the managed systems currently connected to the HMC: \n";
      $cmd = "ssh $hmc lssysconn -r all -F type_model_serial_num,state";        	#define command to be run
      open(SSH,"$cmd |") or die "$!\n";
      while (<SSH>) {
         print $_;
      }
      close SSH;						#close filehandle
      exit 1; 							#exit script
   }								#end of unless block
}                                                               #end of subroutine



sub verify_managed_system {
   #
   print "running verify_managed_system subroutine \n" if ($verbose eq "yes");
   #
   # This subroutine is used to verify that the user specified a valid managed system as a command line parameter
   #
   # Sample command output on HMC
   # hscroot@hmc1:~> lssysconn -r all
   # resource_type=sys,type_model_serial_num=9009-22A*7803XXX,sp=primary,sp_phys_loc=U78D3.001.WZS00BP-P1-C1,ipaddr=192.168.139.57,alt_ipaddr=unavailable,state=Connected
   # resource_type=sys,type_model_serial_num=9009-22A*7803YYY,sp=primary,sp_phys_loc=U78D3.001.WZS00D9-P1-C1,ipaddr=192.168.240.5,alt_ipaddr=unavailable,state=Connected
   #
   # Use the following command syntax to make the output easier to parse
   # hscroot@hmc1:~> lssysconn -r all -F type_model_serial_num,state
   # 9009-22A*7803XXX,Connected
   # 9009-22A*7803YYY,Connected
   # 9009-22A*7803ZZZ,No Connection            <--- this would indicate that the managed system previously existed, but is not currently connected to the HMC
   # 9009-22A*7803AAA,Failed Authentication    <--- this would indicate a bad authentication to the FSP on the managed system
   #
   #
   # Programming note:  Since the managed system will often contain the * character, this will confuse regex, because * is a wildcard in regular expresssions.
   # We work around this by using \Q (start quoting metacharacters) and \E (end quoting metacharacters) in the regex.
   #
   my $managed_system_isvalid = "unknown"; 					#initialize variable
   $cmd = "ssh $hmc lssysconn -r all -F type_model_serial_num,state";        	#define command to be run
   print "   running $cmd \n" if ($verbose eq "yes");
   print "   to confirm that $managed_system is being managed by this HMC \n" if ($verbose eq "yes");
   open(SSH,"$cmd |") or die "$!\n";
   while (<SSH>) {
      if ( /\Q$managed_system\E,Connected/ ) {                       		#use \Q and \E to quote the * metacharacter that is commonly used in managed system names
         print "   confirmed that $managed_system is a valid system managed by this HMC \n" if ($verbose eq "yes");
         $managed_system_isvalid = "yes"; 					#update variable 
      }                                                 		        #end of if block
      if ( /\Q$managed_system\E,No Connection/ ) {                  		#use \Q and \E to quote the * metacharacter that is commonly used in managed system names
         print "ERROR: the HMC is not currently connected to the FSP on managed system $managed_system -  Please login to the HMC and validate the managed systems with this command: lssysconn -r all";
         exit 1;
      }                                                         		#end of if block
      if ( /\Q$managed_system\E,Failed Authentication/ ) {                  	#use \Q and \E to quote the * metacharacter that is commonly used in managed system names
         print "ERROR: the authentication password between the HMC and the FSP on managed system $managed_system has a problem, please login to the HMC and validate the managed systems with this command: lssysconn -r all";
         exit 1;
      }                                                         		#end of if block
   }                                                          			#end of while loop
   close SSH;                                                   		#close filehandle
   #
   unless ($managed_system_isvalid eq "yes") {
      print "ERROR: Could not confirm that $managed_system is a valid system being managed by this HMC.  \n";
      print "       You can validate the managed systems connected to the HMC by running this command on the HMC: lssysconn -r all \n";
      print "       These are the managed systems currently detected on the HMC: \n";
      @_ = `$cmd`;
      print @_; 
      exit 1;
   }
}                                                               #end of subroutine



sub get_lpar_names {
   #
   print "running subroutine get_lpar_names \n" if ($verbose eq "yes");
   #
   $cmd = "ssh -q $hmc 'lssyscfg -m $managed_system -r lpar -F \"name,lpar_env,state\" | sort'";
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
   # print output to STDOUT
   print "graph npivgraph { \n";
   print "rankdir=LR\n";
   print "ranksep=.5\n";
   print "nodesep=.4\n";
   #
   # print to $output_file
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
      $cmd = "ssh -q $hmc \"viosvrcmd -m $managed_system -p $vioserver -c 'lsmap -all -npiv -field name physloc clntname fc fcphysloc vfcclient vfcclientdrc -fmt ,'\"";
      print "   running command: $cmd \n" if ($verbose eq "yes");
      #@out = `ssh -q $hmc "viosvrcmd -m $managed_system -p $viosserver -c 'lsmap -all -npiv -field name physloc clntname fc fcphysloc vfcclient vfcclientdrc -fmt ,'"`;
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



sub check_output_file {
   #
   print "running subroutine check_output_file \n" if ($verbose eq "yes");
   #
   my $line_count = 0;						#initialize counter variable
   open(IN,"$output_file") or die "Cannot open output file $output_file $!\n";
   while (<IN>) {
      $line_count++; 						#count the total number of lines in the output file
   }                                                            #end of while loop
   close IN;                                                   #close filehandle
   print "   the output file $output_file contains $line_count lines \n" if ($verbose eq "yes");
   if ( $line_count < 10 ) {
      print "WARNING: the output file $output_file containing the GraphViz DOT-code instructions \n";
      print "         for generating image files is too small, containing only the header and  \n";
      print "         footer details, but not actually any data from the managed system $managed_system.  \n\n";
      print "         This is probably because you used a low-privileged userid to connect to the HMC, \n";
      print "         which did not have sufficient privilege to run the viosvrcmd command on the HMC. \n";
      print "         Please try again with a higher-priviledged userid on the HMC \n\n";
      exit 1;
   }
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
ping_hmc;
ssh_to_hmc;
detect_managed_system;
verify_managed_system;
get_lpar_names;
create_output_file;
print_graphviz_header;
get_details;
print_graphviz_footer;
check_output_file;
create_image_file;

