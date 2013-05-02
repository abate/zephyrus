#!/bin/bash

/usr/bin/time ../zephyrus.native\
 -u           u-ex-2-3.json\
 -spec        spec-ex.spec\
 -ic          ic-ex-empty-4loc.json\
 -out         json ic-ex-first-output-4loc-result.json\
 -out         graph result-first-output-4loc.dot\
 -repo        debian-squeeze ../repositories/repo-debian-squeeze.json\
 -opt         compact\
 -print-all > result-first-4loc.txt 2> time-first-4loc.txt