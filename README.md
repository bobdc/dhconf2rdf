# dhconf2rdf
Convert CSV of Digital Humanities conference data to RDF

This project has scripts that convert data from the [The Index of Digital Humanities Conferences](https://dh-abstracts.library.cmu.edu/). This README file includes a brief demo of how SPARQL queries can go a little further with an RDF version of the data than SQL could with the original relational data

## needed in your path

- The `tarql` CSV-to-RDF SPARQL-based converter from [http://tarql.github.io/](http://tarql.github.io/)

- The `arq` command line SPARQL engine from [https://jena.apache.org/](https://jena.apache.org/) 

## steps to reproduce

1. Download the "Full Data" zip file (not the "Simple CSV") one from [https://dh-abstracts.library.cmu.edu/downloads](https://dh-abstracts.library.cmu.edu/downloads).

2. From this `dhconf2rdf` directory, unzip that zip file so that it creates a `dh_conferences_data/` subdirectory.
 
3. Adjust the `scripts/makeQueries.pl` script if necessary (set `$tarqlPath` to point to where you have tarql) and then run it as shown below. This does two things: 1. it creates a `dhconferences_sparql/*.rq` SPARQL query file for tarql to run on each CSV file from the downloaded zip file and 2. adds a line to `makeRDF.sh` to run `tarql` against the CSV file with that query, putting the output RDF in `dh_conferences_rdf/`.
    ```
       scripts/makeQueries.pl > makeRDF.sh
    ```
4. Make `makeRDF.sh` executable if necessary and run it. This runs all those scripts and puts all that RDF in `dh_conferences_rdf/`

     You now have an RDF equivalent of the original relational data, with URI identifiers for various concepts built around their IDs in the relational data. (For example, Reed College has the ID 3320 in the downloaded `institutions.csv file`, and in `institutions.ttl` it has the URI http://rdfdata.org/dha/institutions/i3320.)

     The next few steps create new RDF to enable the connecting of resources described within the existing RDF by using standard ontologies and data models. They could be done at the command line with arq or within a triplestore like Fuseki, GraphDB, or Blazegraph after loading the above data into the triplestore. Note how the commands below add new RDF to a `newrdf/` subdirectory. 

5. Create [SKOS](https://www.w3.org/2004/02/skos/) versions of the keywords in their own SKOS Scheme: 

    ```
    arq --query scripts/keywords2skos.rq --data dh_conferences_rdf/keywords.ttl > newrdf/skosKeywords.ttl
    ```

6. Create SKOS versions of the topics in their own SKOS Scheme. 

    ```
    arq --query scripts/topics2skos.rq --data dh_conferences_rdf/topics.ttl > newrdf/skosTopics.ttl
    ```

7. Create triples that use the [schema.org](https://schema.org/) schema:keywords property to connect works to keywords: 
    ```
    arq --query scripts/createWorkKeywordTriples.rq --data dh_conferences_rdf/works_keywords.ttl  > newrdf/workKeywordTriples.ttl
    ```
    e.g. `dhaw:i2792  schema:keywords  dhak:i1680 , dhak:i2800 , dhak:i1568 , dhak:i6285 , dhak:i806 .`

    Now the works_keywords.ttl triples are no longer necessary; they were an artifact of the need of relational databases to have a separate table to link rows of one table to another. 

8. Same deal to connect works to topics:

    ```
    arq --query scripts/createWorkTopicTriples.rq --data dh_conferences_rdf/works_topics.ttl  > newrdf/workTopicTriples.ttl
    ```
    
The `newrdf/` directory already has `modelTriples.ttl` in it. This does two things: it creates a new `skos:Concept` with a `skos:prefLabel` of "Text Encoding Initiative (TEI)" and then it adds a `skos:broader` triple to all the SKOS concepts created above that have some version of "TEI" in their name to point to this new concept--essentially, adding a bit of hierarchy to the otherwise flat keyword list currently serving as a taxonomy. 

After loading all of the `ch_ conferences_rdf/` and `newrdf/` data into a triplestore, the following SPARQL query lists all the work titles tagged with "tei", which as of May of 2021 turns out to be 90: 

```
# sample query 1

PREFIX schema: <http://schema.org/> 
PREFIX dha:    <http://rdfdata.org/dha/ns/dh-abstracts/>
PREFIX skos:   <http://www.w3.org/2004/02/skos/core#>

SELECT ?title
WHERE {
  ?keywordURI skos:prefLabel "tei" . 
  ?work schema:keywords ?keywordURI ;
      dha:title ?title .
}
```
Now list the works that are tagged with something in the taxonomic subtree of "Text Encoding Initiative (TEI)" (hereafter, "a TEI keyword"); it turns out to be 132:
```
# sample query 2

PREFIX schema: <http://schema.org/> 
PREFIX dha:    <http://rdfdata.org/dha/ns/dh-abstracts/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT  ?title
WHERE {
  ?teiURI skos:prefLabel "Text Encoding Initiative (TEI)"  . 
  ?keywordURI skos:broader ?teiURI . 
  ?work schema:keywords ?keywordURI ;
      dha:title ?title .
}
```
So adding a little bit of semantics in the form of explicit relationships between related topics has made it possible to find more papers about TEI.

This next query lists the years that papers were submitted with any kind of TEI keyword  and how many were submitted each year: 
```
# sample query 3

PREFIX schema: <http://schema.org/> 
PREFIX dha:    <http://rdfdata.org/dha/ns/dh-abstracts/>
PREFIX skos: <http://www.w3.org/2004/02/skos/core#>

SELECT  ?year (COUNT(?year) AS ?teiPapers)
WHERE {
  ?teiURI skos:prefLabel "Text Encoding Initiative (TEI)"  . 
  ?keywordURI skos:broader ?teiURI . 
  ?work schema:keywords ?keywordURI ;
        dha:conference ?conference . 
  ?conference dha:year ?year . 
}
GROUP BY ?year
ORDER BY ?year
```
The result: 
```
1996: 5
1997: 1
1998: 2
2001: 6
2004: 2
2013: 12
2014: 19
2015: 14
2016: 18
2017: 12
2018: 7
2019: 24
2020: 8
2021: 2
```
