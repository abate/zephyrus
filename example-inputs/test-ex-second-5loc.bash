#!/bin/bash

/usr/bin/time ../zephyrus.native\
 -u           u-ex-3-3.json\
 -spec        spec-ex.spec\
 -ic          ic-ex-first-output-5loc.json\
 -out         json ic-ex-second-output-5loc-result.json\
 -out         graph result-second-output-5loc.dot\
 -repo        debian-squeeze ../repositories/repo-debian-squeeze.json\
 -opt         conservative\
 -print-all > result-second-5loc.txt 2> time-second-5loc.txt