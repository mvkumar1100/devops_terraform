provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "my_instance-one" {
  ami           = "ami-0d16a00c70ee279b8" # Use the appropriate AMI ID
  instance_type = "t2.micro"
  key_name      = "aws_devops"
  tags = {
    Name = "Ec2InstancebyVinodM"
  }
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket = "source-image-bucket-vinod-${random_id.unique.hex}" # Ensure this name is globally unique
  acl    = "private"                                  # Defines the access control list (private by default)

  # Optional: Enable versioning
  versioning {
    enabled = true
  }

  # Optional: Enable logging
  logging {
    target_bucket = "source-image-bucket-vinod-${random_id.unique.hex}"
    target_prefix = "log/"
  }

  # Optional: Set up lifecycle rules
  lifecycle {
    prevent_destroy = true # Prevent accidental deletion of the bucket
  }

  # Tags for the bucket
  tags = {
    Name        = "source-image-bucket-vinod-${random_id.unique.hex}"
    Environment = "Development"
  }
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.lambda_name}_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

# Attach policy to Lambda IAM role
resource "aws_iam_policy" "lambda_policy" {
  name        = "${var.lambda_name}_policy"
  description = "IAM policy for Lambda to access S3 and CloudWatch Logs"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:GetObject", "s3:PutObject"],
        Effect   = "Allow",
        Resource = "${aws_s3_bucket.s3_bucket.arn}/*"
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Create Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "/workspaces/devops_terraform/lambda_function.py"
  output_path = "/workspaces/devops_terraform/lambda_function.zip"
}

resource "aws_lambda_function" "lambda_function" {
  function_name = var.lambda_name
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_execution_role.arn
  handler       = "lambda_function.lambda_handler"
  filename      = data.archive_file.lambda_zip.output_path
  timeout       = 10
}

# Grant S3 permission to invoke Lambda
resource "aws_lambda_permission" "s3_invoke_permission" {
  statement_id  = "AllowS3InvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_bucket.arn
}

# Configure S3 bucket notifications
resource "aws_s3_bucket_notification" "s3_bucket_notification" {
  bucket = aws_s3_bucket.s3_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_function.arn
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".jpg"
  }

  depends_on = [
    aws_lambda_permission.s3_invoke_permission-one
  ]
}

resource "aws_lambda_permission" "s3_invoke_permission-one" {
  statement_id  = "AllowS3InvokeLambda-${random_id.unique_id.hex}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_bucket.arn
}

resource "random_id" "unique_id" {
  byte_length = 4
}

resource "random_id" "unique" {
  byte_length = 4
}

