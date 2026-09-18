# Highly-Available-Azure-Web-Tier
Build and Troubleshoot a Highly Available Azure Web Tier using infrastructure as code.
Highly Available Azure Web Infrastructure. DELETE ALL RESOURCES AFTER EXERCISE COMPLETE>
-------------------------------------------

[Architecture Diagram]

About
-----
Highly available Azure web tier deployed using Bicep.

Technologies
------------
Azure | Bicep | Azure CLI | Linux | NGINX |
Load Balancer | NAT Gateway | Network Watcher

Architecture
------------

Internet
   ↓
Load Balancer
   ↓
VM1 ←→ VM2
   ↓
VNet / Subnet
   ↓
NAT Gateway

Project Highlights
------------------
✓ Infrastructure as Code
✓ Automated validation
✓ Load balancing
✓ Health probes
✓ Explicit outbound networking
✓ Network security
✓ Troubleshooting exercises
✓ Failure simulation
✓ GitHub CI validation

Deployment
----------

az deployment group validate ...

az deployment group what-if ...

az deployment group create ...

Troubleshooting
---------------

Scenario 1 — Failed deployment
Scenario 2 — Backend failure
