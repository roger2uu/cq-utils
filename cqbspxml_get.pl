#!/usr/bin/perl -w
###########################################################################
#
#
#   $Id: cqbspxml_get.pl,v 1.8 2010/07/21 08:55:16 zzhou Exp $
#
#   NAME: 
#   DESC: 
#   CHANGELOG: 
#
#	TODO: 
#
#	zzhou, 2010/06, to read a file with space in the name
#	zzhou, 2010/06, to handle when multiple CQ# in commandline
#	zzhou, 2010/03, merged cqclient.pl
#	zzhou, 2010/02, initial version
#         
#
###########################################################################
use File::Basename;

my $bn = basename($0);
my $dirn = dirname($0);

if ($#ARGV<0) 
{
    print "Usage:\t$bn searchs CQ# from all input text files or file names,\n\tthen try to generate Wind River CQ BSP requirement XML.\n\t$bn <file1 [file2 [file3 ...]]> \n\t$bn WIND00193238 wrl40-bsp-cq.txt\n";

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
undef @in;

my @CQIDs =();
foreach $file ( @ARGV )				# foreach file in cmd list
{

    undef %saw;
    (-f "$file") && push @in, qx(perl -pe 's/(WIND[0-9]{8})/\n\$1\n/gi' < "$file"|egrep -i "WIND[0-9]{8}"|sort -u);
    $file =~ /(WIND[0-9]{8})/i && push (@in, $1);
    @saw{@in} = ();
    @CQIDs = sort keys %saw;
}

foreach $cqid ( @CQIDs )
{
    chomp($cqid);

    ################################		# merge from cqclient.pl
    my $xmlstr = "<ClearQuest>\n\t<requirement id=\"$cqid\"> <Cond_Of_Satisfaction/> </requirement>\n</ClearQuest>\n";
    my @cmdout = ();                            # init command output

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

    if (  $exitval )
    { 
	print "INFO:\t$cqid is not a valid CQ requirement\n";
	next;
    }

    $CQBSP = join( '', @cmdout ); 
    $CQBSP =~ s/&lt;/</g;
    if ($CQBSP !~ m/(<[\s]*BSP_Name[\s]*>)(.*)(<[\s]*\/[\s]*BSP_Name[\s]*>)/is ) {
	print "ERR:\t$cqid is not a valid BSP CQ#. No BSP_Name defined.\n";
	next;
    }

    $bsp = $2;	    $bsp =~ s/\//_/g;
    if ($CQBSP !~ m/<[\s]*Cond_Of_Satisfaction[\s]*>(.*)<[\s]*\/[\s]*Cond_Of_Satisfaction[\s]*>/is) {
	print "ERR:\tnot a valid BSP CQ# XML $cqid. No Cond_Of_Satisfaction section.\n";
	next;
    }

    open FILE, ">$cqid.$bsp.xml" or die "unable to open $cqid.cqxml.xml $!";
    print "INFO:\tThe file '$cqid.$bsp.xml' is generated.\n";
    print FILE $1;
    close FILE;
}

exit( 0 );					# exit

