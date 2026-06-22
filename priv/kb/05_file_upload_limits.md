# File Upload Limits

## Overview

FlowDesk supports common business file uploads with plan-based size limits and a restricted set of file types. Upload failures are typically caused by file size, unsupported extension, network interruption, browser issues, or account-level storage limits.

## Common symptoms

Customers may report that files larger than 100MB fail, uploads stall near completion, a file type is rejected, or one user can upload while another cannot. Browser console errors may mention payload size, timeout, or unsupported media type.

## Likely causes

Likely causes include exceeding the workspace plan limit, uploading a blocked file extension, unstable network connection, expired session, browser extension interference, or the workspace reaching storage quota.

## Troubleshooting steps

1. Confirm the file name, extension, MIME type, and size.
2. Compare the file size against the customer's FlowDesk plan limit.
3. Try a supported smaller test file in the same workspace.
4. Retry in a private browser window with extensions disabled.
5. Check whether workspace storage quota has been reached.
6. Ask for the upload timestamp and browser console error.

## Information to collect from the customer

Collect workspace ID, file name, size, type, plan, storage usage, browser and version, upload timestamp, screenshot, and any request ID or console error.

## Escalation criteria

Escalate if supported files under the limit fail repeatedly, if upload request IDs show server errors, or if multiple customers report upload failures at the same time.

## Customer-facing response template

Thanks for the details. Upload failures are usually tied to size, file type, quota, or browser state. Please confirm the file size and type, try a smaller supported file, and send the timestamp plus any visible error if it still fails.
