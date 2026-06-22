# Webhook Delivery

## Overview

FlowDesk webhooks deliver event payloads to customer-owned HTTPS endpoints. Delivery delays are usually caused by endpoint timeouts, non-2xx responses, DNS issues, TLS problems, or retry backoff after repeated failures.

## Common symptoms

Customers may report delayed events, missing retries, duplicate deliveries, signature verification failures, or webhook events arriving out of order. They may notice that test webhooks work while production events lag.

## Likely causes

Likely causes include endpoint latency above the timeout, returning 4xx or 5xx responses, rejecting FlowDesk signatures, stale webhook secrets, blocked IP ranges, expired TLS certificates, or processing events synchronously instead of acknowledging quickly.

## Troubleshooting steps

1. Confirm the webhook endpoint URL and event type.
2. Ask for the last successful and first failed delivery timestamps.
3. Verify the endpoint returns a 2xx response quickly.
4. Check whether signature verification uses the current webhook secret.
5. Confirm TLS certificates are valid and the endpoint is publicly reachable.
6. Recommend acknowledging quickly and processing asynchronously.

## Information to collect from the customer

Collect workspace ID, webhook ID, endpoint URL, event type, delivery timestamp, response status, request ID, signature verification logs, and recent endpoint deployments.

## Escalation criteria

Escalate if FlowDesk shows successful delivery but the customer never receives the request, if delivery logs are missing, or if multiple customers report delivery delays for the same event type.

## Customer-facing response template

Thanks for the report. Webhook delays often happen when the endpoint times out or returns a non-2xx response. Please confirm the endpoint response code, timestamp, webhook ID, and signature verification result so we can review delivery logs.
