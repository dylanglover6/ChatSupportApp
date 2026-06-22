# Workspace Permissions

## Overview

FlowDesk workspace access is controlled by invitations, roles, group membership, and feature-level permissions. Permission problems often occur when a user accepts an invite with a different email address or belongs to a group that lacks access to a specific area.

## Common symptoms

Customers may report that an invited user cannot access a workspace, a user sees a forbidden page, an admin can access something a teammate cannot, or an SSO user is created without the expected role.

## Likely causes

Likely causes include pending invitations, email alias mismatch, missing SSO group mapping, insufficient role, removed workspace membership, feature disabled for the account, or stale browser session after a role change.

## Troubleshooting steps

1. Confirm the invited email address and the email used at sign-in.
2. Check whether the invitation is pending, expired, or accepted.
3. Verify the user's workspace role and group membership.
4. Confirm the feature is available on the customer's plan.
5. Ask the user to sign out and back in after permission changes.
6. Capture the exact page URL and forbidden message.

## Information to collect from the customer

Collect workspace ID, affected user email, inviter email, role, group mapping, page URL, error text, screenshot, and whether SSO provisioning is enabled.

## Escalation criteria

Escalate if roles and group mappings are correct but access remains blocked, if provisioning creates the wrong membership, or if an audit log review is required.

## Customer-facing response template

Thanks for reaching out. Please confirm the invited email, the email used to sign in, the user's role, and the page URL that shows the access error. After any role change, have the user sign out and back in.
