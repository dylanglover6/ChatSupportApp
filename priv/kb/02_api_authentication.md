# API Authentication

## Overview

FlowDesk API requests use bearer tokens created inside workspace settings. A token can stop working if it is revoked, rotated, copied with whitespace, scoped incorrectly, or sent to the wrong environment. API authentication problems usually appear as HTTP 401 Unauthorized responses.

## Common symptoms

Customers may say the same token worked yesterday, every request returns 401, only one endpoint fails, or a scheduled integration suddenly stopped syncing. The request may succeed in a REST client but fail in production code if headers are formatted differently.

## Likely causes

Common causes include an expired or revoked token, missing `Authorization: Bearer` prefix, accidental newline characters, workspace mismatch, insufficient token scopes, clock skew in signed requests, or using a sandbox token against production.

## Troubleshooting steps

1. Confirm the full HTTP status code and response body.
2. Verify the request includes `Authorization: Bearer TOKEN`.
3. Ask the customer to create a new test token and retry one safe read endpoint.
4. Confirm the request uses the expected FlowDesk environment and workspace.
5. Check token scopes against the endpoint being called.
6. Ask for a redacted curl command that preserves headers and URL path.

## Information to collect from the customer

Collect workspace ID, endpoint path, request ID, timestamp, HTTP method, token scope list, whether the token was recently rotated, and a redacted sample request.

## Escalation criteria

Escalate if a newly created token with correct scopes fails on multiple endpoints, if request IDs show authentication service errors, or if multiple customers report new 401 errors.

## Customer-facing response template

Thanks for reporting this. A 401 usually means FlowDesk did not accept the token or scope for the request. Please retry with a newly generated token, confirm the bearer header format, and send a redacted curl sample plus request ID if it still fails.
