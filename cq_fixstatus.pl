#!/usr/bin/perl -w
###########################################################################
#
#   $Id: cq_fixstatus.pl,v 1.7 2010/07/30 05:44:24 zzhou Exp zzhou $
#
#   NAME: 
#   DESC: 
#   CHANGELOG: 
#
#	TODO: zzhou, 2010/07, ??
#
#	zzhou, 2010/07, initial version
#         
#
###########################################################################
use File::Basename;

my $bn = basename($0);
my $dirn = dirname($0);

if ($#ARGV<0) 
{
    print "Usage:\t$bn searchs CQ# from all input text files or file names,\n\tthen query Defect/Fix status.\n\teg.\n\t$bn <file1 [file2 [file3 ...]]> \n\t$bn WIND00193238 cqlist.txt > wrl-defect-fix-status.csv\n";
    exit 0;
}

###########################################################################
#   globals
###########################################################################
my $server = 'clearquest-xml';                  # cq server
my $port   = 5556;                              # cq server listening port
my $eof    = '</ClearQuest>';                   # end of data tag
my $exitval = 0;                                # exit val (default = 0)
my $cmd = '';                                   # command
my @svrout = ();                                # server output
my $debug = 0;                                  # debug flag
my @files = ();                                 # files to work with
my $shutdown = 1;                               # client shutdown enabled
my @cmdout = ();

###########################################################################
#   Perl goo
###########################################################################
require 5.006;                                  # need this rev for sockets
$| = 1;                                         # don't buffer output
use FileHandle;                                 # autoflush as method
use Socket;                                     # socket io


###########################################################################
#   search CQ# in all input files
###########################################################################

my @cqids =();
my @fixids =();
my %hash_defect_fix = ();
my %hash_defect_priority = ();
my @in = ();
my %defect_repeat_count = ();	# repeat_count for Defect
my %fix_repeat_count = ();	# repeat_count for Fix

# find all CQIDs
foreach $file ( @ARGV )				# foreach file in cmd list
{
    while ($file =~ m/(WIND[0-9]{8})/ig) { push (@in, $1);}

    if (-f "$file") 
    {
	open FH, "<$file";
	while (<FH>)
	{
	    my($line) = $_;
	    chomp($line);
	    while ($line =~ m/(WIND[0-9]{8})/ig) { push @in, $1; }
	}
	close FH;
    }
}

# Check all Defects
# count each CQID, could be fix, could be defect

foreach $cqid ( @in ) { $defect_repeat_count{$cqid} += 1; }
@cqids = sort keys %defect_repeat_count;

foreach $defectid ( @cqids )
{
    chomp($defectid);
    my $xmlstr = "<ClearQuest> <defect id=\"$defectid\"> <Fix/> <Priority/> <State/> <Summary/> </defect> </ClearQuest>";
    $exitval = &cqclient ($xmlstr);
    if ( $exitval )
    { 
	# This is not a valid Defect. Maybe it is a Fix CQ record.
	push (@fixids, $defectid);
	$fix_repeat_count{$defectid} += ($defect_repeat_count{$defectid}-1); # for multiple Fixes from ARGV
	next;
    }

    my $cqtxt = join( '', @cmdout ); 
    $cqtxt =~ m/<Fix>(.*)<\/Fix>/is;
    $temp = 1;
    foreach $fixid ( split /[ \n]+/, $1 ) {
	push (@fixids, $fixid);	
	$temp = ($defect_repeat_count{$defectid}-1);
	$fix_repeat_count{$fixid} += $temp; 	# for multiple Defects from ARGV
	$temp = 0;
    }

    $cqtxt =~ m/<State>(.*)<\/State>/is;
    my $defect_state = $1;

    $cqtxt =~ m/<Priority>([0-9]).*<\/Priority>/is;
    $hash_defect_priority{$defectid} = "P$1";

    # No Fix for this defect.
    if ($temp) 
    {
	$cqtxt =~ m/<Summary>(.*)<\/Summary>/is;
    	my $defect_summary = $1;
	$hash_defect_fix{$defectid}{"na"} = "defect $defect_state, na, $defect_summary";
    }



}

# Update Fix's information
foreach $fixid ( @fixids ) { $fix_repeat_count{$fixid} += 1; }
@fixids = sort keys %fix_repeat_count;

foreach $fixid ( @fixids ) 
{
    my $xmlstr = "<ClearQuest> <fix id=\"$fixid\"> <State/> <Defect/> <Release/> <Summary/> </fix> </ClearQuest>";
    $exitval = &cqclient ($xmlstr);
    if (  $exitval )
    { 
	print STDERR "'$fixid' is not a valid Defect or Fix.\n";
	next;
    }
    my $cqtxt = join( '', @cmdout ); 

    $cqtxt =~ m/<State>(.*)<\/State>/is;
    my $state = $1;

    $cqtxt =~ m/<Release>(.*)<\/Release>/is;
    my $release = $1;

    $cqtxt =~ m/<Defect>(.*)<\/Defect>/is;
    my $defectid = $1;

    $cqtxt =~ m/<Summary>(.*)<\/Summary>/is;
    my $fix_summary = $1;

    $hash_defect_fix{$defectid}{$fixid} = "fix $state, $release, $fix_summary";

    if (!defined ( $hash_defect_priority{$defectid} ))
    {
	$xmlstr = "<ClearQuest> <defect id=\"$defectid\"> <Priority/> </defect> </ClearQuest>";
    	$exitval = &cqclient ($xmlstr);
    	( $exitval ) && print STDERR "'$defectid': error to retrieve info.\n";

	$cqtxt = join( '', @cmdout ); 
    	$cqtxt =~ m/<Priority>([0-9]).*<\/Priority>/is;
    	$hash_defect_priority{$defectid} = "P$1";
    }
}


# Reporting
$fix_repeat_count{"na"} = 0;
$temp = 1;
foreach $defectid ( keys %hash_defect_fix ) 
{
    ($temp) && (print "priority, defectid, fixid, count, state, target_release, summary\n")&&($temp=0);
    $deref = $hash_defect_fix{$defectid};
    foreach $fixid ( keys %$deref ) {
	$count = $fix_repeat_count{$fixid};

	if (defined ($defect_repeat_count{$defectid})) 
	{
		if ($fix_repeat_count{$fixid} < $defect_repeat_count{$defectid}) 
		{ $count = $defect_repeat_count{$defectid}; }
	}

	print "$hash_defect_priority{$defectid},$defectid,$fixid,$count,$hash_defect_fix{$defectid}{$fixid}\n";
    }
}

exit( 0 );					# exit





################################
#
#   INPUT: 
#	$xmlstr, XML plain text required by ClearQuest.
#   OUTPUT: 
#	$exitval, 0 success, others fails
#	@cmdout, the txt output from ClearQuest
#
################################
sub cqclient
{
    my ($xmlstr) = @_;
    @cmdout =();

    ################################		# merge from cqclient.pl
    # my $xmlstr = "<ClearQuest>\n\t<requirement id=\"$defectid\"> <Cond_Of_Satisfaction/> </requirement>\n</ClearQuest>\n";
    # my $xmlstr = "<ClearQuest> <defect id=\"$defectid\"> <Fix/> <State/> </defect> </ClearQuest>";
    # my @cmdout = ();                            # init command output

    my $proto = getprotobyname( 'tcp' );        # get protocol num for tcp
    my $iaddr = inet_aton( $server );           # convert hostname to bin ip
    my $paddr = sockaddr_in( $port, $iaddr );   # resolve socket address

                                               	# create socket
    socket( SOCK, PF_INET, SOCK_STREAM, $proto ) or die( "socket: $!" );
                                               	# connect to socket
    connect( SOCK, $paddr ) or die( "ERR: unable to connect to '$server'!\n" );
    autoflush SOCK 1;                           # don't buffer to socket
    print( SOCK "$xmlstr\n" );                  # send command through socket
    shutdown( SOCK, 1 ) if ( $shutdown );       # we're done writing if enabled

    $exitval = 0;
    while ( $_ = <SOCK> )                       # while data in socket
    {
	if ( $_ =~ /status='error'/o )          # error detected
	{
	    $exitval = 1;                       # set bad exit val
	}
	push( @cmdout, $_ );                    # save command output
	last if ( $_ =~ /$eof/ );               # stop read if end of data
    }
    close( SOCK );                              # close the socket
    
    ################################		# end merge cpclient.pl

    return $exitval;
}



