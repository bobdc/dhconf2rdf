# Run this script from the repository's root directory.
scripts/makeQueries.pl > makeRDF.sh
chmod +x makeRDF.sh
./makeRDF.sh
arq --query scripts/keywords2skos.rq --data dh_conferences_rdf/keywords.ttl > newrdf/skosKeywords.ttl
arq --query scripts/topics2skos.rq --data dh_conferences_rdf/topics.ttl > newrdf/skosTopics.ttl
arq --query scripts/createWorkKeywordTriples.rq --data dh_conferences_rdf/works_keywords.ttl  > newrdf/workKeywordTriples.ttl
arq --query scripts/createWorkTopicTriples.rq --data dh_conferences_rdf/works_topics.ttl  > newrdf/workTopicTriples.ttl
