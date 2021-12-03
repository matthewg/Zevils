#!/usr/bin/python3
"""Turn a Google Form into a ranked-choice election.
See https://zevils.com/2021/12/quick-ranked-choice-elections-with.html ."""

import csv
import re
import sys

import pyrankvote


NUMBER_OF_SEATS = 2  # Adjust this!
candidates = []
ballots = []

reader = csv.reader(sys.stdin)
for line in reader:
    if not candidates:
        # This is the header line. Ignore the "Timestamp" column and turn everything else into a Candidate.
        candidates = [pyrankvote.Candidate(c) for c in line[1:]]
        continue

    ballot_selections = []
    for idx, ordinal in enumerate(line[1:]):
        # This is a vote of 'ordinal' for candidate candidates[idx]
        if not ordinal:
            # Candidate was not ranked on this ballot
            continue
        ranking = int(re.sub(r'[^0-9]+', '', ordinal))
        ballot_selections.append((ranking, candidates[idx]))
    ballot_selections.sort(key=lambda c: c[0])
    ranked_candidates = list(map(lambda c: c[1], ballot_selections))
    ballots.append(pyrankvote.Ballot(ranked_candidates=ranked_candidates))

election_result = pyrankvote.single_transferable_vote(candidates, ballots, number_of_seats=NUMBER_OF_SEATS)
print(election_result)
