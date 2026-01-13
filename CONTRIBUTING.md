# Contributing to AWS Autoscaling with EC2 Image Builder

Thank you for your interest in contributing to this project! This educational infrastructure project welcomes contributions that improve clarity, functionality, and documentation. Whether you're fixing a typo, improving code quality, or adding new features, your help is appreciated.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)
- [How to Contribute](#how-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Enhancements](#suggesting-enhancements)
  - [Submitting Pull Requests](#submitting-pull-requests)
- [Coding Standards](#coding-standards)
  - [Terraform Style Guide](#terraform-style-guide)
  - [Python Style Guide](#python-style-guide)
  - [Documentation Standards](#documentation-standards)
- [Testing Requirements](#testing-requirements)
- [Pull Request Process](#pull-request-process)
- [Issue Reporting Guidelines](#issue-reporting-guidelines)
- [Community and Communication](#community-and-communication)

---

## Code of Conduct

This project adheres to a simple code of conduct: be respectful, constructive, and collaborative. We're here to learn and build together.

### Our Standards

- **Be Respectful**: Treat all contributors with respect and courtesy
- **Be Constructive**: Provide helpful feedback and actionable suggestions
- **Be Collaborative**: Share knowledge and help others learn
- **Be Patient**: Remember that this is an educational project - questions are welcome

### Unacceptable Behavior

- Harassment, discrimination, or offensive comments
- Spam or irrelevant promotional content
- Publishing others' private information
- Trolling or deliberately disruptive behavior

---

## Getting Started

Before contributing, please:

1. **Read the README**: Familiarize yourself with the project's purpose and architecture
2. **Check existing issues**: See if someone else is already working on similar changes
3. **Understand the scope**: This is an educational project focused on demonstrating AWS automation patterns

### Project Goals

- Demonstrate event-driven infrastructure automation patterns
- Provide clear, educational examples of AWS service integration
- Maintain simplicity and readability for learning purposes
- Follow AWS and Terraform best practices

---

## Development Setup

### Prerequisites

- **Terraform**: >= 1.11.0
- **AWS CLI**: >= 2.0
- **AWS Account**: With appropriate permissions (see README Prerequisites)
- **Git**: For version control
- **Python**: 3.12 (for Lambda function development)
- **Text Editor**: VS Code, Vim, or your preferred editor

### Recommended VS Code Extensions

- HashiCorp Terraform
- Python
- YAML
- Markdown All in One
- AWS Toolkit

### Local Development Environment

1. **Clone the repository**:
   ```bash
   git clone https://github.com/jmcmillan1873/autoscaling-with-imagebuilder.git
   cd autoscaling-with-imagebuilder
   ```

2. **Configure AWS credentials**:
   ```bash
   aws configure --profile your-dev-profile
   export AWS_PROFILE=your-dev-profile
   ```

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Create terraform.tfvars**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your settings
   ```

5. **Validate configuration**:
   ```bash
   terraform validate
   terraform fmt -check
   ```

---

## Project Structure

Understanding the project structure helps you navigate and contribute effectively:

```
autoscaling-with-imagebuilder/
├── main.tf                       # Provider and Terraform configuration
├── variables.tf                  # Input variable definitions
├── locals.tf                     # Computed local values
├── data.tf                       # Data sources and IAM policy documents
├── vpc.tf                        # VPC and networking infrastructure
├── security-group.tf             # Security group definitions
├── iam.tf                        # IAM roles and policies
├── imagebuilder.tf               # EC2 Image Builder resources
├── ec2-asg.tf                    # Launch Template and Auto Scaling Group
├── lambda.tf                     # Lambda functions
├── eventbridge.tf                # EventBridge rules and targets
├── ssm.tf                        # Systems Manager Parameter Store
├── files/                        # Supporting files
│   ├── ltupdater_lambda_function.py           # Launch Template updater Lambda
│   ├── amicleaner_lambda_function.py          # AMI cleanup Lambda
│   ├── imagebuilder_component_os_tools.tpl    # OS tooling component
│   └── imagebuilder_component_custom_scripts.tpl  # Custom scripts component
├── README.md                     # Project documentation
├── CONTRIBUTING.md               # This file
├── LICENSE                       # Project license
└── terraform.tfvars.example      # Example configuration
```

---

## How to Contribute

### Reporting Bugs

Found a bug? Help us fix it by providing detailed information:

**Before submitting a bug report:**
- Check if the bug has already been reported in Issues
- Verify you're using the latest version of the code
- Test with a clean deployment to rule out configuration issues

**When reporting a bug, include:**

1. **Clear title**: Describe the issue concisely
2. **Description**: What happened vs. what you expected
3. **Steps to reproduce**: Numbered list of steps
4. **Environment details**:
   - Terraform version (`terraform version`)
   - AWS region
   - Relevant Terraform/AWS provider versions
5. **Error messages**: Complete error output (sanitize sensitive data)
6. **Screenshots**: If applicable
7. **Logs**: Relevant CloudWatch or Terraform logs

**Bug Report Template:**
```markdown
## Bug Description
Brief description of the issue

## Expected Behavior
What should happen

## Actual Behavior
What actually happens

## Steps to Reproduce
1. Step one
2. Step two
3. Step three

## Environment
- Terraform version: 
- AWS region: 
- OS: 

## Error Messages
```
[Paste error messages here]
```

## Additional Context
Any other relevant information
```

### Suggesting Enhancements

Have an idea for improvement? We'd love to hear it!

**Enhancement suggestions should include:**
- **Clear description**: What you want to achieve
- **Use case**: Why this enhancement is valuable
- **Proposed solution**: How it might be implemented
- **Alternatives considered**: Other approaches you thought about
- **Educational value**: How it helps users learn

**Enhancement Request Template:**
```markdown
## Enhancement Description
Brief description of the proposed enhancement

## Problem/Use Case
What problem does this solve or what need does it address?

## Proposed Solution
How would you implement this?

## Educational Value
How does this improve the learning experience?

## Alternatives Considered
What other approaches did you consider?

## Additional Context
Mockups, examples, or related resources
```

### Submitting Pull Requests

Ready to contribute code? Great! Follow these steps:

1. **Fork the repository** to your GitHub account
2. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes** following our coding standards
4. **Test thoroughly** (see Testing Requirements)
5. **Commit your changes** with clear messages
6. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```
7. **Open a Pull Request** with a clear description

---

## Coding Standards

Maintaining consistent code style ensures readability and maintainability.

### Terraform Style Guide

#### Formatting

- **Use `terraform fmt`**: Always format code before committing
  ```bash
  terraform fmt -recursive
  ```
- **2-space indentation**: Consistent across all `.tf` files
- **One resource per block**: Don't combine multiple resources
- **Blank lines**: Separate logical sections

#### Naming Conventions

- **Resources**: Use descriptive names with project prefix
  ```hcl
  # Good
  resource "aws_security_group" "lambda" {
    name = "${var.project}-lambda-sg"
  }
  
  # Avoid
  resource "aws_security_group" "sg1" {
    name = "my-sg"
  }
  ```

- **Variables**: Use `snake_case` with descriptive names
  ```hcl
  # Good
  variable "ami_retain_count" {
    description = "Number of AMIs to retain"
    type        = number
  }
  
  # Avoid
  variable "count" {
    type = number
  }
  ```

- **Locals**: Use `snake_case` for computed values
  ```hcl
  locals {
    account_id = data.aws_caller_identity.current.account_id
    common_tags = merge(var.default_tags, {"ManagedBy": "Terraform"})
  }
  ```

#### Documentation

- **Resource comments**: Explain purpose and relationships
  ```hcl
  # Lambda function for updating Launch Template with new AMI ID
  # Triggered by EventBridge when Image Builder completes
  resource "aws_lambda_function" "update_launch_template" {
    # ...
  }
  ```

- **Variable descriptions**: Clear, comprehensive explanations
  ```hcl
  variable "region" {
    description = <<-EOT
      AWS region for resource deployment. Choose a region close to your users
      or that meets compliance requirements. Common options: us-east-1, eu-west-1
    EOT
    type    = string
    default = "eu-west-1"
  }
  ```

- **Inline comments**: Explain non-obvious configurations
  ```hcl
  # Use $Latest reference to automatically adopt new LT versions
  launch_template {
    id      = aws_launch_template.custom_lt.id
    version = "$Latest"
  }
  ```

#### Organization

- **Group related resources**: Keep related resources together
- **Use separate files**: Don't put everything in one file
- **Logical ordering**: Dependencies first, then dependent resources
- **Data sources**: Keep in `data.tf` unless specific to one file

### Python Style Guide

#### Style Standards

- **PEP 8 compliance**: Follow Python style guide
- **Type hints**: Use where it improves clarity
  ```python
  def _parse_dt(s: str) -> datetime:
      return datetime.fromisoformat(s.replace("Z", "+00:00"))
  ```

- **Docstrings**: Document functions thoroughly
  ```python
  def lambda_handler(event, context):
      """
      Lambda handler for AMI cleanup automation.
      
      Args:
          event (dict): EventBridge scheduled event
          context (object): Lambda context object
          
      Returns:
          dict: Response with status code and execution summary
      """
  ```

#### Lambda Function Standards

- **Error handling**: Graceful error handling with logging
  ```python
  try:
      response = ec2.describe_images(...)
  except ClientError as e:
      logger.error(f"Failed to describe images: {e}")
      raise
  ```

- **Logging**: Use structured logging with appropriate levels
  ```python
  logger.info("Starting AMI retention. retain=%s", RETAIN_COUNT)
  logger.warning("LAUNCH_TEMPLATE_ID not set")
  logger.error("Failed to delete AMI: %s", error)
  ```

- **Environment variables**: Load at module level
  ```python
  # At module level
  RETAIN_COUNT = int(os.getenv("RETAIN_COUNT", "5"))
  
  # Not in handler function
  ```

- **Constants**: Use UPPER_CASE for constants
  ```python
  RETAIN_COUNT = 5
  PROJECT_TAG_VALUE = "MyProject"
  DRY_RUN = True
  ```

### Documentation Standards

#### Markdown Files

- **Headers**: Use ATX-style headers (`#`, `##`, `###`)
- **Code blocks**: Always specify language for syntax highlighting
  ````markdown
  ```bash
  terraform apply
  ```
  
  ```hcl
  variable "example" {
    type = string
  }
  ```
  ````

- **Links**: Use reference-style links for readability
  ```markdown
  [AWS Documentation][aws-docs]
  
  [aws-docs]: https://docs.aws.amazon.com/
  ```

- **Lists**: Use consistent formatting
  - Unordered lists with `-`
  - Ordered lists with `1.`, `2.`, `3.`
  - Nested lists with 2-space indentation

#### Inline Comments

- **Terraform**: Explain "why" not "what"
  ```hcl
  # Good: Explains reasoning
  # Single NAT Gateway reduces costs while maintaining outbound connectivity
  single_nat_gateway = true
  
  # Avoid: States the obvious
  # Set single NAT gateway to true
  single_nat_gateway = true
  ```

- **Python**: Document complex logic
  ```python
  # Good: Explains algorithm
  # Sort versions by version number descending to identify latest
  versions.sort(key=lambda v: v.get("VersionNumber", 0), reverse=True)
  
  # Avoid: Repeats code
  # Sort versions
  versions.sort(...)
  ```

---

## Testing Requirements

All contributions should be tested to ensure they work as expected and don't break existing functionality.

### Pre-Submission Testing

1. **Terraform Validation**:
   ```bash
   # Format check
   terraform fmt -check -recursive
   
   # Validation
   terraform validate
   
   # Plan (should complete without errors)
   terraform plan
   ```

2. **Python Linting** (for Lambda functions):
   ```bash
   # Install linting tools
   pip install pylint flake8
   
   # Run linters
   pylint files/*.py
   flake8 files/*.py --max-line-length=100
   ```

3. **Deployment Testing**:
   - Deploy in a test AWS account
   - Verify all resources create successfully
   - Test the complete workflow:
     1. Manual Image Builder pipeline execution
     2. Lambda function invocation
     3. Launch Template update
     4. Auto Scaling Group behavior

4. **Cleanup Testing**:
   ```bash
   # Ensure clean destruction
   terraform destroy
   # Verify no orphaned resources in AWS Console
   ```

### Testing Checklist

- [ ] `terraform fmt` runs without changes
- [ ] `terraform validate` passes
- [ ] `terraform plan` completes without errors
- [ ] Deployment succeeds in test environment
- [ ] Image Builder pipeline executes successfully
- [ ] Lambda functions execute without errors
- [ ] CloudWatch logs show expected output
- [ ] Launch Template updates correctly
- [ ] Auto Scaling Group uses latest AMI
- [ ] `terraform destroy` removes all resources
- [ ] No manual cleanup required

### Integration Testing

For significant changes, test the complete automation workflow:

1. Deploy infrastructure
2. Trigger Image Builder pipeline manually or wait for scheduled execution
3. Verify EventBridge triggers Lambda
4. Check Lambda function logs
5. Verify Launch Template version creation
6. Test Auto Scaling behavior
7. Verify AMI cleanup (if applicable)

---

## Pull Request Process

### Before Submitting

1. **Update documentation**: README, inline comments, docstrings
2. **Run tests**: All tests must pass
3. **Format code**: `terraform fmt`, Python linting
4. **Update CHANGELOG**: If the project has one
5. **Squash commits**: Combine related commits for clean history

### Pull Request Template

```markdown
## Description
Brief description of changes

## Motivation and Context
Why is this change needed? What problem does it solve?

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that changes existing behavior)
- [ ] Documentation update
- [ ] Code refactoring

## Testing Performed
Describe the tests you ran and their results

## Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in complex areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings or errors
- [ ] I have tested this in a real AWS environment
- [ ] I have verified terraform destroy works correctly

## Screenshots (if applicable)
Add screenshots to demonstrate changes

## Additional Notes
Any additional information for reviewers
```

### Review Process

1. **Automated checks**: CI/CD runs (if configured)
2. **Peer review**: At least one maintainer review
3. **Testing**: Reviewer may test in their environment
4. **Feedback**: Address review comments
5. **Approval**: Maintainer approves changes
6. **Merge**: Maintainer merges PR

### After Merge

- **Update your fork**: Sync with main repository
- **Close related issues**: Reference PR in issue closure
- **Celebrate**: You've contributed to open source!

---

## Issue Reporting Guidelines

### Issue Labels

We use labels to categorize issues:

- **bug**: Something isn't working correctly
- **enhancement**: New feature or improvement
- **documentation**: Documentation improvements
- **question**: Questions about usage or implementation
- **help wanted**: Issues where contributions are welcome
- **good first issue**: Good for newcomers
- **wontfix**: Issue will not be addressed
- **duplicate**: Issue already reported

### Issue Lifecycle

1. **New**: Issue is created
2. **Triaged**: Maintainer reviews and labels
3. **In Progress**: Someone is working on it
4. **Review**: PR submitted, under review
5. **Resolved**: Fixed and merged
6. **Closed**: Issue is complete

---

## Community and Communication

### Where to Get Help

- **GitHub Issues**: For bugs, features, and questions
- **GitHub Discussions**: For general discussions and Q&A
- **README**: Comprehensive project documentation
- **Code Comments**: Inline documentation explains details

### Response Times

This is a community project maintained by volunteers:

- **Bug reports**: Response within 1-3 business days
- **Pull requests**: Initial review within 3-5 business days
- **Questions**: Response within 1-5 business days

### Being a Good Community Member

- **Search first**: Check existing issues and discussions
- **Be specific**: Provide details and context
- **Be patient**: Maintainers are volunteers
- **Pay it forward**: Help others when you can
- **Share knowledge**: Document what you learn

---

## Recognition

Contributors are recognized in several ways:

- **GitHub Contributions**: Your commits appear in the repository history
- **Release Notes**: Significant contributions mentioned in releases
- **Documentation**: Major contributors mentioned in README
- **Community**: Recognition in discussions and issues

---

## Questions?

If you have questions about contributing:

1. Check existing documentation (README, this file)
2. Search closed issues for similar questions
3. Open a new issue with the "question" label
4. Be specific about what you need help with

Thank you for contributing to this educational project and helping others learn AWS automation patterns!

---

## Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Documentation](https://docs.aws.amazon.com/)
- [Python PEP 8 Style Guide](https://peps.python.org/pep-0008/)
- [Markdown Guide](https://www.markdownguide.org/)
- [GitHub Flow Guide](https://guides.github.com/introduction/flow/)
- [Conventional Commits](https://www.conventionalcommits.org/)

---

**Last Updated**: 2024-01-15
