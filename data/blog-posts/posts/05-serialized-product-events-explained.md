---
title: "Serialized Product Events, Explained: Identifiers, EPCIS, and the Handoff"
slug: serialized-product-events-explained
date: 2026-01-29
description: A conceptual introduction to product identifiers and event exchange, grounded in the GS1 US chain-of-custody guideline.
tags: [EPCIS, traceability, supply chain]
reading_time: 7 minutes
hero_image: "[VERIFY: select a brand-compliant image; see IMAGE-MANIFEST.md]"
---

Product identity and event history answer related but different questions. Identity helps parties refer to the product consistently. An event record describes something that happened as the product moved through a process.

The GS1 US Pharmaceutical Chain-of-Custody Guideline describes serialized product chain-of-custody events and standardized data exchange using EPCIS across participants including manufacturers, repackagers, wholesalers, third-party logistics providers and reverse-logistics partners. This article summarizes that standards-oriented context at a high level; it does not prescribe a legal transaction or say which records a particular organization must create. ([GS1 US guideline](https://www.gs1us.org/industries-and-insights/by-industry/healthcare/standards-in-use/pharmaceutical/chain-of-custody))

## Product identity and event history

An identifier is a way to refer to an item or other relevant object within the applicable data model. An event record gives context about an activity involving that identity. A team needs both concepts to discuss movement clearly, but the exact data elements and implementation depend on the systems and rules that apply to the transaction.

## The GS1 chain-of-custody model

### Who records an event

The GS1 US guideline addresses exchange among supply-chain participants, including manufacturers, repackagers, wholesalers, logistics providers and reverse-logistics participants. Each organization should understand which records it supplies, which it receives and how a discrepancy is routed.

### What EPCIS contributes

The guideline describes EPCIS in the context of standardized event communication. For an operational discussion, ask whether the trading partners can exchange the event information they need, identify the source of each record and resolve gaps without losing the connection to the product and partner context.

## A simple illustrative handoff

Imagine a shipment moving from one organization to another. The parties agree how to identify the product and trading partners, record the relevant handoff in their systems, exchange information and route an exception if the expected data is absent. This example is illustrative only. It is not a prescribed event sequence or a complete data set.

## Interoperability questions

- Which partner owns each event record?
- How are product and location references aligned?
- What happens when a record is late, missing or inconsistent?
- Can the buyer retrieve evidence needed for its own quality review?
- Who resolves the issue and confirms closure?

## Standards are not a substitute for applicable regulation

A standards guideline explains a technical model; it does not, on its own, establish all legal duties. The research base could not reach the FDA DSCSA page. Before making compliance claims, verify current primary sources and the relevant jurisdiction, product and effective date with your own compliance function.

**Related reading:** [A buyer's field guide to traceability]([VERIFY: internal route]); [Returns and recalls]([VERIFY: internal route]); [Build an audit-ready distribution record]([VERIFY: internal route]).

**Editorial image note:** Do not imply a stock photograph depicts serialization, EPCIS, a barcode scan or Core Distro's actual process unless that is verified.