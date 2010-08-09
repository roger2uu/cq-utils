#!/usr/bin/perl -w
###########################################################################
#
#   $Id: cqbspxml_ana.pl,v 1.6 2010/07/01 02:59:56 zzhou Exp $
#
#   NAME: 
#   DESC: 
#   CHANGELOG: 
#
#
#
#	TODO: zzhou, 2010/04, to add boot method, to detect <KGDB_Serial>Y-S</KGDB_Serial>, ...
#
#	zzhou, 2010/06, detect board name/revision, remove empty CPU templates
#	zzhou, 2010/03, initial version
#
#
#
###########################################################################
use File::Basename;


my $bn = basename($0);
my $dirn = dirname($0);

if ($#ARGV<0) 
{
    print "Usage:\t$bn is used to Analyze Wind River CQ BSP XML requirement.\n";
    print "\teg,\n";
    print "\t$bn <file1 [file2 [file3 ...]]> \n\t$bn WIND00*.xml > bsp.csv\n";
}

# print the header line.
print "CQ#,BSP,TYPE,ITEMS\n";

foreach $file ( @ARGV )				# foreach file in cmd list
{
    if (-f $file) {                             # if argument is a file

	open ( FILE, "<$file" ); 
	my @buf = <FILE>;
	close (FILE);

	my $fn2cqnum = "";
	if ( $file =~ m/(WIND[0-9]*)/i ) 
    	{
		$fn2cqnum = $1;
	} else {
		$fn2cqnum = "na";
	}


	$bsp = "";
	foreach $line (@buf)
	{
		if ( $line =~ m/(<[\s]*BSP_Name[\s]*>)(.*)(<[\s]*\/[\s]*BSP_Name[\s]*>)/is ) 
		{ 
			$bsp=$2;
 			#print "\t$bsp\n"; 
			foreach $line1 (@buf)
			{ 
				$_ = $line1;
				m/(<[\s]*Kernel[_\s]*Type[\s]*>)(.*)(<[\s]*\/[\s]*Kernel[_\s]*Type[\s]*>)/is && print "$fn2cqnum,$bsp,kernel,$2\n";
				m/(<[\s]*Kernel[_\s]*Type[\s]*=[\s]*"[\s]*)(.*)([\s]*")/is && print "$fn2cqnum,$bsp,kernel,$2\n"; 
			}
		}
	}
	!$bsp && ( print "ALARM: No BSP_Name in '$file'.\n" ) && next;

	foreach $_ (@buf)
	{
		
		# to detect if support multiple boards on this BSP
		if (/<[\s]*Board_Revision[\s]*>(.*)<[\s]*\/[\s]*Board_Revision[\s]*>/is){
		 	my @board_rev=split(/[,]+/, $1);
			if ( scalar(@board_rev) > 1 ) {
				foreach $item (@board_rev) { 
					$item =~ s/^\s+//; $item =~ s/\s+$//;
					print "$fn2cqnum,$bsp,board_rev,$item\n"; 
			}}
		}
		if (/<[\s]*Board_Name[\s]*>(.*)<[\s]*\/[\s]*Board_Name[\s]*>/is){
		 	my @board_name=split(/[,]+/, $1);
			if ( scalar(@board_name) > 1 ) {
				foreach $item (@board_name) { 
					$item =~ s/^\s+//; $item =~ s/\s+$//;
					print "$fn2cqnum,$bsp,board_name,$item\n"; 
		}}}


		if (/<[\s]*CPU_Template[\s]*>(.*)<[\s]*\/[\s]*CPU_Template[\s]*>/is){
			my $str1=$1;
			if ($str1 =~ m/[\w]+/){print "$fn2cqnum,$bsp,cpu_template,$str1\n";}
		}

		(/<[\s]*Processor_Family[\s]*>(.*)<[\s]*\/[\s]*Processor_Family[\s]*>/is) && print "$fn2cqnum,$bsp,procfam,$1\n";

		if (/<[\s]*Device[\s]*name="[\s]*(.*)[\s]*"/.../\/[\s]*Device[\s]*>/is){
			$1 && ($dev_n = $1) && (m/<[\s]*support[\s]*>.*Y-S.*<[\s]*\/[\s]*support[\s]*>/is) && (print "$fn2cqnum,$bsp,tc_device,$dev_n\n"); }
		(/<[\s]*HW_Watchdog[\s]*>[\s]*Y[\s]*-[\s]*S[\s]*<[\s]*\/[\s]*HW_Watchdog[\s]*>/is) && (print "$fn2cqnum,$bsp,tc_device,watchdog\n");

		if (/<[\s]*Bus[\s]*>/.../<[\s]*\/[\s]*Bus[\s]*>/is){
			(m/<[\s]*([\S]*)[\s]*support=[\s]*\"Y-S\"[\s]*>/is) && (print "$fn2cqnum,$bsp,tc_bus,$1\n"); }

		if (/<[\s]*Root_Methods[\s]*>/.../<[\s]*\/[\s]*Root_Methods[\s]*>/is){
			(m/<(.*)>[\s\"]*Y-S[\s\"]*/is) && (print "$fn2cqnum,$bsp,tc_root_type,$1\n"); }



	}
    } else {
	print "$file - not a file!\n\n";        # print error message
	next;                                   # get next file
    }
}

exit( 0 );					# exit


