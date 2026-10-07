# Docs (proxy: hand-typed JIRA descriptions; no typed docs exist in the corpus)

Verbatim typed messages, chosen for register range. Slack mentions and links are rendered as displayed. Ids are from stylometrics.py --dump.

### Problem and two bullets
2025-07-25, CP-5906

> There is work we can do cleaning up our paper data (especially in elastic) that can improve the speed of queries and reduce costs dramatically.
> - Optimizing elastic schema
> - Archiving papers in GCS

### Proposal
2025-07-22, CP-5875

> We may want to add keywords on the basis of customer, document, topic, etc. We should have a way to automatically append those keywords to specific documents (papers or patents) as they get put into elastic.

### Behaviour spec
2025-10-07, CP-6346

> Should pause while the iterator is returning it’s answers, and return to the caller when we have information to show thinking in the UI “sequentially”.
