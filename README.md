# npivgraph
npivgraph for visualizing NPIV virtual fibre channel on IBM VIOS

Forked from the original script by Brian Smith at https://npivgraph.sourceforge.net/

npivgraph for visualizing NPIV mappings in a PowerVM environment
npivgraph is a Perl program designed to visualize the Virtual Fibre Channel (VFC) / NPIV adapter mappings in a PowerVM environment. 

It visualizes how VIO servers contain HBA's which are mapped to Virtual Fibre Server adapters, which are connected to Virtual Client Adatpers, which are attached to LPAR's. 

It also validates that the LPAR's have NPIV access through more than 1 VIO server, if not a red warning message is displayed (see screenshot below).

Here is a example screenshot:
<img src=images/npivgraph1.png>

This can be helpful to validate your configuration is setup how you want and for documentation purposes.   It can also visually show which physical VIO HBA's might be over utilized or under utilized based on how many clients are attached to each HBA. 

# npivgraph Screen Shots

This screen shot shows how the graph can optionally be filtered down to only include a specific VIO server (-v flag) and one of its specific HBA's (-f flag).  This can be very helpful for large systems where you need to break it up in to smaller graphs. 
<img src=images/npivgraph2.png>

Here is a screen shot showing a single LPAR being graphed with the "-l" flag. 
<img src=images/npivgraph3.png>

# Installation / Use
Download the perl script from:  https://sourceforge.net/projects/npivgraph/files/
or 
```
git clone https://github.com/nickjeffrey/npivgraph
cd npivgraph
chmod +x npivgraph.pl
```

You must run the script from a server that has SSH keys setup with your HMC.  

```
Usage ./npivgraph.pl -h hmcserver -m managedsystem [-l lpar] [-f fcs] [-v vioserver]
 -h specifies hmcserver name (can also be username@hmc)
 -m specifies managed system name
 [-l lpar] only graph on specific lpar and its VIO servers
 [-f fcs]  only graph specified vio FCS adapter (i.e. - "-f fcs2")
 [-f vioserver]  only graph adapters on specified vio (i.e. - "-v vio1")
```

# Examples:
```
Graph all:
   ./npivgraph.pl -h hscroot@hmcserver1 -m p520
Graph only fcs0 VIO adapter(s):
   ./npivgraph.pl -h hscroot@hmcserver1 -m p520 -f fcs0
Graph only aixtest01 LPAR:
   ./npivgraph.pl -h hscroot@hmcserver1 -m p520 -l aixtest01
Graph only things connected to vio2:
   ./npivgraph.pl -h hscroot@hmcserver1 -m p520 -v vio2
Graph only things connected to vio2 on fcs0:
   ./npivgraph.pl -h hscroot@hmcserver1 -m p520 -f fcs0 -v vio2
```

The script produces DOT code that Graphviz can turn in to a graph.  You will need to have Graphviz installed somewhere to produce the graph. 

You have the following options on where to install Graphviz:
Windows - Download from http://www.graphviz.org/    After installing on Windows, run the npivgraph.pl script from whereever, and redirect the output to a file.   Transfer this file to your Windows computer and graph it with Graphviz.

Linux - It is in most distro's repositors and very easily installable.  After installing on Linux, run the npivgraph.pl script from whereever, and redirect the output to a file.   Transfer this file to your Linux computer and graph it with Graphviz.

AIX -  It is also possible to install Graphviz on AIX, but more difficult.  See http://www.perzl.org/aix/ for AIX binaries of Graphviz.

If you have Graphviz installed on the computer you are running the script from you can run npivgraph.pl and pipe the output to the graphviz dot command to create the graph like this:

```
./npivgraph.pl -h hscroot@hmcserver1 -m p520 -f fcs0 -v vio2 | dot -Tpng -o npiv.png
```

If you have graphviz installed on a different computer from where you are running the npivgraph.pl script, do this:   Run npivgraph.pl and redirect the output to a file.   Transfer this file to where you have graphviz installed and run a command like this:

```
  cat output.txt | dot -Tpng -o npiv.png
```

# Related scripts
http://pslot.sourceforge.net/

http://graphlvm.sourceforge.net/


# License / Disclaimer
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
