schemaVersion: 1.0
name: InstallOSPackages
description: Update system packages and install developer tooling
phases:
  - name: build
    steps:
      - name: UpdatePackages
        action: ExecuteBash
        inputs:
          commands:
            - dnf -y update
            - dnf -y groupinstall "Development Tools"
