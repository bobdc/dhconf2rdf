#!/usr/bin/perl

# typically run as
# ./scripts/makeQueries.pl > makeRDF.sh

# This script uses tarql to convert dh_conferences data to RDF and
# assumes that:
# 
# 1. the "Full Data" zip file of CSV files from
# https://dh-abstracts.library.cmu.edu/downloads is unzipped into the
# child directory dh_conferences_data/
#     
# 2. additional child directories dh_conferences_sparql/ and
# dh_conferences_rdf/ are empty and ready for input
# 
# Running this perl script (no parameters necessary) will read the
# first line of each file in dh_conferences_data and use its first line
# to create a conversion query for that file in
# dh_conferences_sparql. (For example, it will read
# dh_conferences_data/works.csv and create
# dh_conferences_sparql/works.rq.)
# 
# The standard output of this script creates a shell script that runs
# the queries against the CSV files and puts turtle files of the
# results in dh_conferences_rdf. (For example, one line of the script
# will run dh_conferences_sparql/works.rq against
# dh_conferences_data/works.csv to create
# dh_conferences_rdf/works.ttl.)

# For any properties listed in the foreignKeyFields arrays it will
# create URIs for the values (and, crucially, for references to those
# values) from the numeric IDs instead of just using the numeric
# ID. So, for example, in works_topics.ttl,
# <http://rdfdata.org/dha/works_topics/i1> has a dha:work value of
# <http://rdfdata.org/dha/work/i1579> instead of just 1579. ("i"
# prefix added in case anyone ever serializes the data as RDF/XML; XML
# doesn't like seeing a digit at the start of a local name.)
 
use strict;

# constants
my $URIStub = "http://rdfdata.org/dha";
my $tarqlPath="~/bin/tarql-1.2/bin/tarql";

my @foreignKeyFields = ("conference","organizer","country", "organizer", "institution", "author", "affiliation", "work", "keyword", "topic", "work_type");

# initialize
my $file = "";
my $filename = "";
my $i = 0;


# Read each CSV file and make: 
# - the query to convert it 
# - the shell # script command to run that

foreach $file (<dh_conferences_data/*.csv>) { 

    open(INPUT,$file);

    # Pull filename to use for creating output file and class name.
    $filename = $file;
    $filename =~ s/.*\/(.+)\.csv/$1/;     # delete chars before & after filename
    my $className = $filename;
    my $classNameForURI = $className ;  # may be overridden below
    # If the class name has no underscores and it's a plural, make it singular.
    if (index($className,"_") == -1) {
	$className =~ s/s$//;
        $classNameForURI = $className ;   # save version that doesn't get initial capped
	$className =~ s/(.)(.+)/\U\1\E$2/;  # initial cap the class name
	if ($className eq "Countrie") {     # account for irregular one
	    $className = "Country"; 
	}
    }
    
    my $queryPart1 = "PREFIX dha:  <$URIStub/ns/dh-abstracts/>\nCONSTRUCT {\n  ?u a dha:$className ;\n";

    # The SPARQL files created will be input to tarql.
    my $tarqlInputPath = "dh_conferences_sparql/$filename.rq";

    # Print to stdout for the shell script that runs the queries.
    print "$tarqlPath $tarqlInputPath > dh_conferences_rdf/$filename.ttl\n";

    open(OUTPUT,">$tarqlInputPath");

    print OUTPUT $queryPart1;

    # And for query part 2, read line 1 of CSV file to get field names. 

    my @fieldNames = "";
    while (<INPUT>) {
	if ($. == 1) {    # if it's the first line, which has field names
	    chop($_);
	    s/\"//g;
	    @fieldNames = split(/,/,$_);

	    for ($i = 0; $i < @fieldNames; $i++) {
		my $fieldName = $fieldNames[$i];

		# Write out triple pattern to show CONSTRUCT what to make.
		print OUTPUT "  dha:$fieldName ";
		# If the property is a foreign key field, reference
		# its value as a URI.
		if (grep( /^$fieldName$/, @foreignKeyFields)) {
		    print OUTPUT "?$fieldName" . "URI ;\n";
		}
		else {
		    print OUTPUT " ?$fieldName ;\n";
		}
	    }
	    print OUTPUT ".\n";
	}
    };
    close(INPUT);    # All done reading the CSV.

    print OUTPUT "}\nFROM <file:../dh_conferences_data/$filename.csv>\n";

    # Query's WHERE clause gets BIND statements creating URIs of
    # values referenced above. Following assumes that all the input
    # tables have an id field, which was the case on 2020-10-05.

    print OUTPUT "WHERE {\n";

    # First define the URI variable used as the triple pattern subjects.
    print OUTPUT "BIND (URI(CONCAT(\"$URIStub/$classNameForURI/i\",?id)) AS ?u)\n";

    # Define URI variables for each field that we will reference as a URI. 
    for ($i = 0; $i < @fieldNames; $i++) {
	my $fieldName = $fieldNames[$i];
	if ( grep( /^$fieldName$/, @foreignKeyFields ) ) {
	    print OUTPUT "BIND (URI(CONCAT(\"$URIStub/$fieldName/i\",?$fieldName)) AS ?$fieldName" . "URI)\n";
	}
    }

    print OUTPUT "}\n";
    
    close(OUTPUT);
}

################

