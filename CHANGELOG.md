# Changelog

All notable changes to this project will automatically be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v0.3.0 - 2025-10-20

### What's Changed

Move to this version Out of Hours, due to the move to azapi, it will make some slight adjustment to the gw and will result in a drop of vpn connections.

#### 🐛 Bug Fixes

* enhancement: GW Got replaced whenever you added a new group with split tunnel, this is aan issue in the azurerm provider, bool:true on the internet_security_enabled, this change to azapi_resource does not have that issue. (#5) @Blankf

#### 📖 Documentation

* enhancement: added some information about the usage with all types or profiles @Blankf

**Full Changelog**: https://github.com/schubergphilis/terraform-azure-mcaf-vwan-p2s/compare/v0.2.2...v0.3.0

## v0.2.2 - 2025-10-17

### What's Changed

#### 🐛 Bug Fixes

* bug: make the radius block more optional for others (#4) @Blankf

**Full Changelog**: https://github.com/schubergphilis/terraform-azure-mcaf-vwan-p2s/compare/v0.2.1...v0.2.2

## v0.2.1 - 2025-10-16

### What's Changed

#### 🐛 Bug Fixes

* bug: due to issues with the API always returning an empty radius {} (#3) @Blankf

**Full Changelog**: https://github.com/schubergphilis/terraform-azure-mcaf-vwan-p2s/compare/v0.2.0...v0.2.1

## v0.2.0 - 2025-04-09

### What's Changed

#### 🚀 Features

* enhancement: swap internet_security_enabled to general variable (#2) @Blankf

**Full Changelog**: https://github.com/schubergphilis/terraform-azure-mcaf-vwan-p2s/compare/v0.1.0...v0.2.0

## v0.1.0 - 2025-03-10

### What's Changed

* No changes

**Full Changelog**: https://github.com/schubergphilis/terraform-azure-mcaf-update-management/compare/...v0.1.0
