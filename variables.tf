variable "lambda_function_actions" {
  type        = map(string)
  description = "Map of the names of Lambda functions to create alarms for, with the function name as the key and the value as `notify` or `alarm_only`"
}

variable "activation_build_name" {
  type        = string
  description = "Name of the Activation CodeBuild build to monitor for failures"
}

variable "deactivation_build_name" {
  type        = string
  description = "Name of the Deactivation CodeBuild build to monitor for failures"
}

variable "sender_email_address" {
  type        = string
  description = "Name of the Deactivation CodeBuild build to monitor for failures"
}

variable "admin_email_address" {
  type        = string
  description = "Name of the Deactivation CodeBuild build to monitor for failures"
}

variable "lab_status_topic_arn" {
  type        = string
  description = "ARN of the Lab Status SNS topic to send messages to"
}

variable "tags" {
  type        = map(string)
  description = "Map of tags for the DDB table"
  default     = null
}