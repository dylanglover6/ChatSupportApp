# SSO SAML Troubleshooting

## Overview

FlowDesk workspaces can use SSO with a SAML identity provider such as Okta, Azure AD, or OneLogin. Most failed SAML sign-ins are caused by a mismatch between the identity provider configuration and the FlowDesk workspace SSO settings. The most common issue is an audience or entity ID mismatch after a workspace admin copies values between systems.

## Common symptoms

Customers may report an "audience mismatch" error, a blank redirect loop, an invalid recipient message, or successful IdP authentication followed by a FlowDesk login failure. Some users may be able to log in while others cannot if the issue is tied to group assignment.

## Likely causes

Likely causes include the wrong audience URI, incorrect ACS URL, expired signing certificate, missing user email attribute, or a user not assigned to the FlowDesk application in the identity provider. Recent IdP app cloning and workspace domain changes are strong signals.

## Troubleshooting steps

1. Confirm the FlowDesk workspace slug and SSO domain.
2. Compare the IdP audience URI with the FlowDesk SAML entity ID.
3. Compare the ACS URL in the IdP with the FlowDesk ACS URL.
4. Confirm the certificate is active and not expired.
5. Verify the user is assigned to the FlowDesk app and sends an email attribute.
6. Ask the customer to retry in a private browser session and capture the exact timestamp.

## Information to collect from the customer

Collect workspace ID, IdP name, affected user email, exact error text, timestamp with timezone, recent IdP changes, and a screenshot of the SAML app settings with secrets hidden.

## Escalation criteria

Escalate if the customer confirms all values match and the issue still reproduces, if multiple workspaces are affected, or if backend SAML assertion logs are needed.

## Customer-facing response template

Thanks for the details. This looks like a SAML configuration mismatch. Please confirm the audience URI, ACS URL, assigned user, and certificate status in your identity provider, then send the exact error and timestamp if the issue continues.
