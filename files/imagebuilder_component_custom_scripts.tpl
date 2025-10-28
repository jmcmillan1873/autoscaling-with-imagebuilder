schemaVersion: 1.0
name: DownloadCustomScripts
description: Add custom commands you want to execute here
phases:
  - name: build
    steps:
      - name: DoCustomStuff
        action: ExecuteBash
        inputs:
          commands:
            - echo "### Setup default aws region" >> /var/log/custom_component_log 2>&1
            - sudo -u ec2-user aws configure set region ${region} --profile default
            - echo "### Create directory CamelCase Directory for some reason" >> /var/log/custom_component_log 2>&1 
            - sudo -u ec2-user mkdir SomeDirectory  >> /var/log/custom_component_log 2>&1 
