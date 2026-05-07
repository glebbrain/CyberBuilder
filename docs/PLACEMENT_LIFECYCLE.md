# Placement Lifecycle (v0.4)

## Purpose

Defines canonical placement request states and allowed transitions for Placement Wrapper v0.4.

## Request States

- `pending`
- `validated`
- `delegated`
- `placed`
- `failed`
- `removed`

## Allowed Transitions

- `pending -> validated`
- `pending -> failed`
- `validated -> delegated`
- `validated -> failed`
- `delegated -> placed`
- `delegated -> failed`
- `placed -> removed`
- `placed -> failed`

Terminal states in current implementation:

- `failed`
- `removed`

## State Semantics

- `pending`: request created, not yet validated.
- `validated`: request passed safety/authorization checks.
- `delegated`: request handed off to provider.
- `placed`: provider placement completed successfully.
- `failed`: request failed validation, delegation, or provider execution.
- `removed`: previously placed object metadata marked removed.

## Provider States

Provider availability is tracked separately with:

- `available`
- `missing`
- `disabled`
- `unsupported_version`
- `runtime_error`

Provider states gate delegation but do not change request transition rules.

---

Last reviewed: 2026-05-07.
