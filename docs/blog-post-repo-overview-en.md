# From Legacy Hadoop to OCI Object Storage: A Practical Migration Lab with Podman

Modernizing Hadoop workloads is rarely about rewriting everything. In most real environments, especially in regulated sectors like banking, teams need a controlled path: keep existing logic, validate behavior, and migrate storage with minimal risk.

That is exactly what this repository provides.

## Why this repo exists

This lab was built to demonstrate a practical migration path from classic HDFS-based processing to Oracle Cloud Infrastructure (OCI) Object Storage, while preserving familiar big data components:

- HDFS
- YARN
- Hive
- Spark
- OCI HDFS Connector

Everything runs in a single Podman container so you can reproduce the setup quickly on a local machine.

## What you can do with it

The repo includes a realistic banking-style workload (daily account balance aggregation) and lets you run it in multiple modes:

1. Classic Hadoop mode over HDFS
2. Migrated mode to OCI Object Storage with minimal code/config changes
3. Spark-on-YARN mode writing to OCI

This gives you a side-by-side comparison of behavior and output parity.

## Core migration idea

The key design principle is **minimal change migration**:

- Keep business logic intact
- Change storage URIs and connector/config wiring
- Validate outputs are identical

In other words, this repo focuses on reducing migration risk by proving that storage can change without forcing a full application rewrite.

## Architecture highlights

The lab uses:

- Podman image with Hadoop + YARN + Hive + Spark
- OCI HDFS Connector (`com.oracle.oci.sdk:oci-hdfs-connector`)
- Startup scripts that inject OCI credentials at runtime (not baked into image)
- Read-only mount strategy for sensitive key material
- Scripts for repeatable build/run/test flows

It also documents operational endpoints (NameNode, YARN, JobHistory, HiveServer2) so you can inspect each service during execution.

## Security approach

A major concern in migration labs is secret hygiene. This repo enforces a safer local pattern:

- OCI secrets are externalized in local env files
- Private keys are mounted from local `.oci/` in read-only mode
- Sensitive files are excluded from git

That makes it suitable for demo and experimentation without normalizing bad security habits.

## What we learned (practical lessons)

Running mixed ecosystems (Hadoop + Spark + OCI SDK dependencies) can introduce classpath conflicts, especially around Guava/Jersey/JAX-RS.  
This repo captures those realities and includes runnable workarounds so the end-to-end flow remains operational.

That is often the most valuable part of a migration lab: not just “happy path” scripts, but documented fixes for integration friction.

## Who this is for

This repository is useful for:

- Data platform engineers validating OCI connectivity patterns
- Teams planning phased Hadoop storage migrations
- Architects who need a demo with realistic constraints (security, compatibility, parity testing)
- Practitioners who want reproducible local experiments before moving to shared environments

## Conclusion

If your goal is to move from legacy HDFS-centric workloads to OCI Object Storage without a disruptive rewrite, this lab gives you a concrete starting point.

It is hands-on, reproducible, and centered on real migration priorities:
**parity, safety, and incremental change**.
