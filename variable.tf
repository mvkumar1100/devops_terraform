variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "lambda_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "vinod-ukp_lambda"
}