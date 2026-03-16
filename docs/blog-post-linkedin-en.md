# Migrating Hadoop Storage to OCI Without Rewriting Your Workloads

Most Hadoop modernization discussions jump straight to “rewrite everything.” In practice, that is rarely how migration works, especially in banking and other regulated environments.

Teams usually need a lower-risk path:
- keep existing business logic,
- move storage incrementally,
- and prove output parity before scaling.

I built this repository as a hands-on lab for exactly that scenario.

## What the lab includes

A single Podman container running:
- HDFS
- YARN
- Hive
- Spark
- OCI HDFS Connector

And a realistic banking-style workload that computes daily balances, executed in three ways:
1. Classic HDFS flow
2. OCI-migrated flow with minimal changes
3. Spark on YARN writing to OCI

It is intentionally designed as a local, reproducible testbed. You can bring the stack up quickly, run the jobs, inspect service UIs, and validate outputs end to end without introducing extra infrastructure dependencies.

## Why this matters

The migration pattern is intentionally simple: change URIs and connector/config wiring, not business logic.

That allows teams to validate behavior quickly and reduce risk:
- same logic,
- same expected output,
- different storage backend.

For organizations with legacy Hadoop jobs, this is often the most practical first step.

This approach is especially useful when teams need confidence before broader platform decisions. Instead of debating migration feasibility in abstract terms, you can validate a concrete workload, measure behavior, and document tradeoffs using the same job logic.

## Security and operational choices

The repo also follows secure local practices:
- no OCI secrets baked into images,
- credentials injected at runtime,
- key material mounted read-only,
- sensitive files ignored by git.

Operational endpoints are documented too (NameNode, YARN, JobHistory, HiveServer2), so you can inspect service state while testing.

That matters because migration testing is not just about successful job completion. You also need operational visibility: service health, execution progress, and enough observability to troubleshoot quickly when something breaks.

## Real-world lesson: dependency friction is part of migration

A valuable part of this lab is not only the happy path, but also the classpath and dependency issues that appear in mixed Hadoop/Spark/OCI stacks.

These are common in real migration projects. The repo includes practical workarounds and runnable scripts so the flow remains reproducible.

In other words, this is not a “hello world” demo that skips hard parts. It captures the type of integration friction teams actually face when combining legacy components with cloud connectors, and it documents what worked in a way others can reuse.

## What you can validate quickly with this repo

- Whether existing Hadoop-style transformations can move to OCI-backed paths with minimal change.
- Whether output parity is preserved between HDFS and OCI runs.
- Whether your team can operate and debug the stack with known endpoints and scripts.
- Whether Spark-on-YARN is a better transitional path than forcing every MapReduce flow immediately.

That gives engineering and architecture teams useful evidence for planning phased migration roadmaps.

## Who should use this

- Platform engineers validating OCI object storage integration
- Teams planning phased Hadoop migrations
- Architects who need proof of parity before larger platform shifts

## Final thought

You do not need a big-bang rewrite to start modernizing Hadoop storage.

A controlled, parity-first migration is possible and often more effective.

This lab gives you a concrete, reproducible way to test that path end to end.
