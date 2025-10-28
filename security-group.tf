resource "aws_security_group" "MyExampleSG" {
  name        = "${var.project}-sg"
  description = "Egress-only SG for scanbox"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    description = "allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${var.project}-sg"
  }
}


resource "aws_security_group" "lambda" {
  name        = "lambda-sg"
  description = "SG for Lambda functions"
  vpc_id      = module.vpc.vpc_id

  egress {
    description = "allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "lambda-sg"
  }
}
