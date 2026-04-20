# Accelerate Your macOS Intune Journey with Intune My Macs

**A production-ready starter kit for Microsoft Intune macOS device management**

---

Managing macOS devices in an enterprise environment can be challenging—especially when you're just getting started with Microsoft Intune. Between configuring security policies, setting up compliance baselines, deploying applications, and ensuring a smooth user onboarding experience, there's a lot of ground to cover. That's where **Intune My Macs** comes in.

## What is Intune My Macs?

Intune My Macs is an open-source project from the Microsoft Intune Customer Experience Engineering team that allows you to deploy a complete macOS proof-of-concept in minutes rather than days. It's a curated collection of 38+ enterprise-grade configurations, policies, scripts, and applications—all deployable through a single PowerShell script.

The project operates in **dry-run mode by default**, letting you preview exactly what will be created before committing any changes to your Intune tenant. When you're ready, simply add the `--apply` flag to deploy.

## Why Would You Use It?

### 1. Jumpstart Your macOS Management

Instead of building configurations from scratch, you get a proven baseline that covers:

- **Security policies**: FileVault encryption, Firewall, Gatekeeper, guest account restrictions
- **System configuration**: Login window settings, screensaver idle time, NTP time synchronization
- **Compliance baselines**: Minimum macOS version requirements, encryption enforcement, System Integrity Protection checks
- **Application management**: Microsoft 365, Edge browser policies, Company Portal deployment
- **Identity**: Platform Single Sign-On (SSO) with Microsoft Entra ID

### 2. Learn Best Practices by Example

Each configuration in the repository serves as a practical reference implementation. The naming conventions follow a consistent pattern (e.g., `pol-sec-001-filevault`, `scr-app-100-install-company-portal`), and detailed documentation explains what each setting does and why it's configured that way.

### 3. Reduce Time to Value

What might take weeks of research, configuration, and testing can be deployed in approximately 5 minutes. The script handles:

- Microsoft Graph SDK authentication
- Policy creation via Settings Catalog and custom configuration profiles
- Script deployment with proper execution settings
- PKG application uploads
- Optional group assignments

### 4. Optional Microsoft Defender for Endpoint Integration

If you're evaluating Microsoft Defender for Endpoint on macOS, the project includes an optional `--mde` flag that deploys the full MDE configuration—including system extensions, privacy preferences, network filter settings, and the installation script.

## What's Actually Deployed?

The repository includes configurations across several categories:

| Category | Examples |
|----------|----------|
| **Security** | FileVault disk encryption, Firewall enablement, Gatekeeper assessment, Login window hardening |
| **Compliance** | macOS 15.0 minimum version, SIP enforcement, encryption requirements |
| **Identity** | Platform SSO for Entra ID authentication |
| **Applications** | Swift Dialog for onboarding UI, Office 365 settings, Edge browser policies |
| **Scripts** | Company Portal installation, Dock customization, Escrow Buddy for FileVault key recovery |
| **Custom Attributes** | Hardware compatibility checker, Intune agent version reporting |

## How It Works

The deployment is driven by XML manifest files that define each configuration artifact. The main PowerShell script reads these manifests, resolves the associated JSON/mobileconfig/script files, and creates the corresponding objects in Intune via the Microsoft Graph API.

```bash
# Preview what would be created
pwsh ./mainScript.ps1 --assign-group "Intune Mac Pilot"

# Actually deploy the configurations
pwsh ./mainScript.ps1 --assign-group "Intune Mac Pilot" --apply
```

You can scope deployments to specific artifact types using flags like `--apps`, `--config`, `--compliance`, `--scripts`, or `--custom-attributes`. A custom naming prefix (`--prefix`) keeps your deployed objects easily identifiable, and `--remove-all` provides a clean way to delete everything created by a previous run.

## Bonus: Utility Tools

The project also includes several analysis and documentation tools:

- **Export-MacOSConfigPolicies.ps1** — Back up existing Intune macOS policies to JSON
- **Find-DuplicatePayloadSettings.ps1** — Detect conflicting settings across your configuration files
- **Generate-ConfigurationDocumentation.py** — Create Markdown or Word documentation from the manifests
- **Get-IntuneAgentProcessingOrder.ps1** — Understand script and app processing sequence
- **Get-MacOSGlobalAssignments.ps1** — Audit policies assigned to All Devices or All Users

## Getting Started

**Prerequisites:**
1. PowerShell 7+ (works on macOS, Windows, or Linux)
2. An Intune tenant with MDM authority configured
3. An Apple Push Notification Service (APNS) certificate for macOS enrollment
4. Appropriate Microsoft Graph permissions (Intune Administrator or equivalent)

**Quick start:**
```bash
git clone https://github.com/microsoft/intune-my-macs.git
cd intune-my-macs
pwsh ./mainScript.ps1 --assign-group "Your Pilot Group" --apply
```

## Summary

Intune My Macs isn't meant to be a one-size-fits-all production deployment—it's a solid starting point. Use it to quickly stand up a proof-of-concept, learn from the configuration patterns, and adapt the policies to your organization's specific requirements.

Whether you're evaluating Intune for macOS management, building out a new tenant, or just looking for reference implementations of common security configurations, this project can save you significant time and effort.

---

*Built by the Microsoft Intune Customer Experience Engineering team*

**Resources:**
- [GitHub Repository](https://github.com/microsoft/intune-my-macs)
- [Full Configuration Documentation](INTUNE-MY-MACS-DOCUMENTATION.md)
- [Microsoft Defender for Endpoint Setup](mde/README.md)
