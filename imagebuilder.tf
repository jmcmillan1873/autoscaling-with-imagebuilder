# Define the components containing custom commands, and install scripts required for our environment: 
resource "aws_imagebuilder_component" "custom_scripts" {
  name     = "download-custom-scripts"
  platform = "Linux"
  version  = "1.0.0"

  data = templatefile("${path.module}/files/imagebuilder_component_custom_scripts.tpl", {
    region = var.region
  })
}

resource "aws_imagebuilder_component" "os_tooling" {
  name     = "al2023-os-tooling"
  platform = "Linux"
  version  = "1.0.0"
  data     = templatefile("${path.module}/files/imagebuilder_component_os_tools.tpl", {})
}

#########

# Create the recipe for the custom image using the components listed abouve
resource "aws_imagebuilder_image_recipe" "custom_recipe" {
  name         = "al2023-custom-recipe"
  version      = "1.0.0"
  parent_image = data.aws_ssm_parameter.al2023.value

  component { component_arn = aws_imagebuilder_component.os_tooling.arn }
  component { component_arn = aws_imagebuilder_component.custom_scripts.arn }

  lifecycle {
    create_before_destroy = true
  }
}

# Define the VPC/Infra used to build the image in
resource "aws_imagebuilder_infrastructure_configuration" "infra" {
  name                          = "al2023-custom-infra"
  instance_profile_name         = aws_iam_instance_profile.imagebuilder.name
  instance_types                = var.build_instance_types
  subnet_id                     = module.vpc.private_subnets[0]
  security_group_ids            = [aws_security_group.MyExampleSG.id]
  terminate_instance_on_failure = true

  tags = {
    Name = "al2023-custom-imagebuilding"
  }
}

# Although we'll using this in one account/region, adding a distribution config
# allows for the possibility of expanding to different regions/accounts over time
# and also simplifies the process of consuming the ami name/tags.
# distribution.tf
resource "aws_imagebuilder_distribution_configuration" "dist" {
  name = "${var.project}-dist"

  distribution {
    region = var.region

    ami_distribution_configuration {
      name        = "${var.project}-{{imagebuilder:buildDate}}"
      description = "Custom pre-baked AL2023 image"

      ami_tags = {
        OS       = "AmazonLinux2023"
        Hardened = "true"
        Name     = "${var.project}-{{imagebuilder:buildDate}}"
      }
    }

    ssm_parameter_configuration {
      parameter_name = aws_ssm_parameter.custom_built_custom_id.name
      ami_account_id = local.account_id
    }
  }
}

# Define the Imagebuilder pipeline schedule: 
# pipeline.tf
resource "aws_imagebuilder_image_pipeline" "pipeline" {
  name                             = "${var.project}-pipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.custom_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.infra.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.dist.arn
  status                           = "ENABLED"
  enhanced_image_metadata_enabled  = true

  # Weekly bake (02:00 UTC on Sunday). Change to taste.
  schedule {
    schedule_expression                = "cron(0 2 ? * TUE *)"
    pipeline_execution_start_condition = "EXPRESSION_MATCH_ONLY"
  }

  image_tests_configuration {
    image_tests_enabled = true
    timeout_minutes     = 60
  }
}

