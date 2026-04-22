# Generate-ConfigurationDocumentation.py

A Python script that generates comprehensive documentation for all Intune macOS configuration artifacts in the repository.

## Overview

This script parses configuration files throughout the repository and produces a complete documentation file (`INTUNE-MY-MACS-DOCUMENTATION.md`) cataloging all policies, profiles, scripts, and packages with their settings.

### Supported Artifact Types

| Type | Source Files | Description |
| ---- | ------------ | ----------- |
| Settings Catalog | `.json` | Modern Intune declarative policies |
| Custom Config | `.mobileconfig` | Traditional Apple configuration profiles |
| Compliance Policy | `.json` | Device compliance requirements |
| Shell Scripts | `.sh`, `.zsh` | Automated scripts (metadata from XML manifest) |
| Packages | `.pkg` | Application installers (metadata from XML manifest) |
| Custom Attributes | `.sh`, `.zsh` | Device inventory scripts (metadata from XML manifest) |

## Requirements

- **Python 3.7+**
- **python-docx** (optional) - Required for DOCX generation
- **pandoc** (optional) - Alternative DOCX converter with better formatting

Install optional dependencies:

```bash
pip install -r tools/requirements.txt
```

## Usage

### Basic Usage - Generate Markdown

```bash
# From repository root
python3 tools/Generate-ConfigurationDocumentation.py
```

Output: `INTUNE-MY-MACS-DOCUMENTATION.md` at repository root

### Parameters

| Parameter | Description |
| --------- | ----------- |
| `--docx` | Also generate a Word document (`.docx`) |
| `--pandoc` | Use pandoc for DOCX conversion (better formatting, requires pandoc installed) |
| `--mde` | Include Microsoft Defender for Endpoint (`mde/`) folder in documentation |

### Examples

#### Generate Markdown Only

```bash
python3 tools/Generate-ConfigurationDocumentation.py
```

#### Generate Markdown and Word Document

```bash
python3 tools/Generate-ConfigurationDocumentation.py --docx
```

#### Generate with Pandoc (Better Formatting)

```bash
python3 tools/Generate-ConfigurationDocumentation.py --docx --pandoc
```

#### Include MDE Configurations

```bash
python3 tools/Generate-ConfigurationDocumentation.py --mde
```

## Output

### Markdown Document

The generated `INTUNE-MY-MACS-DOCUMENTATION.md` contains:

1. **Cover Page** - Project title, generation date, artifact count
2. **About Section** - Project description and what's included
3. **Index Table** - Clickable reference IDs linking to detailed sections
4. **Detailed Configuration** - Per-artifact breakdown with:
   - Reference ID and type
   - Description (from XML manifest)
   - Source file path
   - Settings count
   - Complete settings table (Key/Value pairs)

### Word Document (Optional)

When `--docx` is specified, generates `INTUNE-MY-MACS-DOCUMENTATION.docx` with:

- Professional formatting (Aptos font)
- Styled tables with grid borders
- Monospace font for settings keys
- Cover page with large headings
- Page breaks between major sections

## How It Works

### File Discovery

The script searches these paths:

- `configurations/intune/*.json`
- `configurations/entra/*.json`
- `configurations/**/*.json`
- `configurations/intune/*.mobileconfig`
- `configurations/entra/*.mobileconfig`
- `mde/*.json` (only with `--mde` flag)

### Settings Extraction

| File Type | Extraction Method |
| --------- | ----------------- |
| Settings Catalog JSON | Recursive traversal of `settings[].settingInstance` structures |
| Compliance Policy JSON | Flat property extraction with metadata filtering |
| Mobileconfig | Plist parsing via `plistlib`, payload content extraction |
| Scripts/Packages | XML manifest parsing for metadata |

### Value Simplification

The script cleans up Intune's verbose value formats:

- Removes duplicated key prefixes from choice values
- Converts `_true`/`_false` suffixes to `True`/`False`
- Truncates long strings (>120 chars)
- Preserves placeholder tokens like `{{variable}}`

Example transformation:

```text
Before: com.apple.filevault2_enable_0
After:  0

Before: com.apple.systempolicy_EnableAssessment_true
After:  True
```

### Metadata Enrichment

For each configuration file, the script looks for a companion `.xml` manifest file with the same base name. If found, it extracts:

- `Name` - Display name
- `Description` - Policy description
- `Type` - Artifact classification

## Configuration File Locations

The script expects this repository structure:

```text
intune-my-macs/
├── configurations/
│   ├── intune/           # Settings Catalog and mobileconfig files
│   │   ├── pol-*.json
│   │   ├── pol-*.xml     # Manifest files
│   │   ├── cfg-*.mobileconfig
│   │   └── cfg-*.xml
│   └── entra/            # Entra-specific configurations
├── mde/                  # Microsoft Defender configs (optional)
├── apps/                 # Package manifests
├── scripts/              # Shell script manifests
└── custom attributes/    # Custom attribute manifests
```

## Example Output

### Index Section

```markdown
| Ref | Type | Settings Count |
|-----|------|----------------|
| [pol-sec-001-filevault](#pol-sec-001-filevault-policy) | Policy | 8 |
| [cfg-sec-001-login-window](#cfg-sec-001-login-window-customconfig) | CustomConfig | 5 |
| [cmp-cmp-001-macos-baseline](#cmp-cmp-001-macos-baseline-compliance) | Compliance | 12 |
```

### Detailed Configuration Section

```markdown
### pol-sec-001-filevault (Policy)

Enable FileVault disk encryption on all managed macOS devices.

**Source:** `configurations/intune/pol-sec-001-filevault.json`
**Settings:** 8

| Key | Value |
|-----|-------|
| `com.apple.MCX_FileVaultOptions.Enable` | `true` |
| `com.apple.MCX_FileVaultOptions.Defer` | `true` |
| `com.apple.MCX_FileVaultOptions.DeferForceAtUserLogin` | `true` |
```

## Troubleshooting

| Issue | Solution |
| ----- | -------- |
| `[WARN] Failed to parse JSON` | Check for UTF-8 BOM or malformed JSON |
| `[WARN] Failed to parse mobileconfig plist` | Verify plist is valid binary or XML format |
| `[WARN] python-docx not installed` | Run `pip install python-docx` for DOCX support |
| `[WARN] --pandoc requested but pandoc not found` | Install pandoc or remove `--pandoc` flag |
| Duplicate entries in output | Script deduplicates by (ref, type, relpath) tuple |

## Related Tools

- [Export-MacOSConfigPolicies.ps1](Export-MacOSConfigPolicies.md) - Export policies from live Intune
- [Find-DuplicatePayloadSettings.ps1](Find-DuplicatePayloadSettings.md) - Find duplicate settings

## Notes

- The script handles UTF-8 BOM in JSON files automatically
- Large payloads (>60 settings) are included in full (no truncation)
- The MDE folder is excluded by default to keep documentation focused on core configurations
- DOCX generation post-processes tables to enable autofit and apply consistent styling
