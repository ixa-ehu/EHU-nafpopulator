#!/usr/bin/perl

use strict;
use File::Temp qw/ tempfile tempdir /;
use XML::LibXML;
use FindBin qw($Bin);
use Digest::MD5 qw(md5 md5_hex md5_base64);

# default values
our $jdkloc;
our $kstoolsloc;
our $ksserver;
require "$Bin/config.pl";

my $stdinchunk;
{
local $/;
$stdinchunk = <STDIN>;
}


my $parser = XML::LibXML->new();
my $doc= eval {$parser->parse_string($stdinchunk);};

if ($@) {
    print STDERR "ERROR: Invalid XML.\n";
    exit();
}


my $xc = XML::LibXML::XPathContext->new( $doc->documentElement()  );

my @nodelist = $xc->findnodes('/NAF/nafHeader/public');
my $urival = "";

if (@nodelist) { $urival = $nodelist[0]->findvalue('./@uri'); }

if ($urival eq "") {
    # create fake <public> , uri
    my $digest = md5_hex($stdinchunk);
    $urival = "http://www.newsreader-project.eu/fakes/$digest.xml";
    my $publicelem = "<public publicId=\"$digest\" uri=\"$urival\"/>";
    my $i = index($stdinchunk, "<nafHeader>") + length "<nafHeader>";
    my $incr=0;
    if (substr($stdinchunk,$i,1) eq "\n") {$incr = 1;}
    substr($stdinchunk, $i+$incr, 0) = $publicelem."\n";
}


my $tmpdir = File::Temp->newdir( DIR => "/tmp", CLEANUP=>1 );
my $filename = $tmpdir."/".((split(/\//,$urival))[-1]);

open IFILE, ">$filename" or die "Cannot create $filename\n";
print IFILE $stdinchunk;
close IFILE;

# upload file:

# set enviroment
$ENV{'JAVA_HOME'}="$Bin/$jdkloc";

# system call to NAF populator
print STDERR "EXEC: $Bin/$kstoolsloc/bin/ksnaf.sh -u $ksserver -n $filename\n";
system "$Bin/$kstoolsloc/bin/ksnaf.sh -u $ksserver -n $filename &> $filename.log";

my $resup = `egrep 'File already exists in KS, discarded' $filename.log`;

if ($resup ne "")  {

    print STDERR "ERROR: File already exists in KS, discarded.\n";

} else {

    my $urival_f = $urival;
    $urival_f =~ s/:/\%3A/g;
    $urival_f =~ s/\//\%2F/g;
    system "wget -q \"$ksserver/ui?action=lookup&id=$urival_f\" -O $filename.download";

    my $resdown = `egrep '1 resource found' $filename.download`;

    if ( $resdown ne "" ) {

	print STDERR "INFO: File correctly uploaded.\n";

    } else {

	print STDERR "ERROR: File not uploaded.\n";

    }

}

# print input NAF file for the next component

print $stdinchunk;

