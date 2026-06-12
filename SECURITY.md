# Security Policy

RetroSmart is a local BLE prototype, not a production-secure smart-home platform.

## Current Security Scope

The current repo does not provide:

- cloud authentication
- remote access controls
- encrypted command channels beyond the platform BLE behavior
- OTA update signing
- production-grade device provisioning

Do not use the current prototype for safety-critical control, unattended high-power actuation, or deployments where malicious local BLE access would create unacceptable risk.

## Reporting Issues

For non-sensitive safety or security concerns, open a GitHub issue and include:

- affected app or firmware version/commit
- hardware module involved
- reproduction steps
- expected and actual behavior
- whether physical actuation was involved

For exploitable vulnerabilities that should not be public immediately, use GitHub private vulnerability reporting if enabled on the repository, or contact the maintainer privately before posting details.

## Safety-Relevant Notes

- Motor and servo modules should fail safe on disconnect where possible.
- Automation execution is foreground-only and should not be treated as a reliable unattended safety mechanism.
- Shared ground and adequate actuator power are required for stable hardware behavior.
- Power-bank keep-alive should be solved with appropriate hardware rather than hidden firmware motion.
