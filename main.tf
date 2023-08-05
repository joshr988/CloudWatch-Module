resource "aws_cloudwatch_metric_alarm" "lambda" {
  for_each = toset(keys(var.lambda_function_actions))

  alarm_name                = "lambda_alarm_${each.value}"
  alarm_description         = "Monitor ${each.value} function for errors"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "Errors"
  namespace                 = "AWS/Lambda"
  period                    = 60
  statistic                 = "Sum"
  threshold                 = 1
  insufficient_data_actions = []
  tags                      = var.tags

  dimensions = {
    FunctionName = each.value
  }
}

# Can't track Lambda failures directly, so we'll track when the alarm state becomes ALARM
resource "aws_cloudwatch_event_rule" "lambda" {
  for_each = toset([
    for key, value in var.lambda_function_actions : key if value == "notify"
  ])

  name        = "lambda_notify_${each.value}"
  description = "Send a notification when the CloudWatch alarm for the ${each.value} function changes to an ALARM state."
  tags        = var.tags

  event_pattern = <<EOF
{
  "source": [
    "aws.cloudwatch"
  ],
  "detail-type": [
    "CloudWatch Alarm State Change"
  ],
  "detail": {
    "alarmName": [
      "${aws_cloudwatch_metric_alarm.lambda[each.value].alarm_name}"
    ],
    "state": {
      "value": ["ALARM"]
    }
  }
}
EOF
}

# Don't need to track alarm state to nofity, but having an alarm to watch is still nice
resource "aws_cloudwatch_metric_alarm" "codebuild" {
  for_each = toset([var.activation_build_name, var.deactivation_build_name])

  alarm_name                = "codebuild_alarm_${each.value}"
  alarm_description         = "Monitor ${each.value} build for failures"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 1
  metric_name               = "FailedBuilds"
  namespace                 = "AWS/CodeBuild"
  period                    = 60
  statistic                 = "Sum"
  threshold                 = 1
  insufficient_data_actions = []
  tags                      = var.tags

  dimensions = {
    ProjectName = each.value
  }

}

# Track build state directly, since we can alert on each failure
resource "aws_cloudwatch_event_rule" "codebuild_activation" {
  name        = "codebuild_notify_activation_failures"
  description = "Send a notification when the CodeBuild lab activation build fails"
  tags        = var.tags

  event_pattern = <<EOF
{
  "source": [ 
    "aws.codebuild"
  ], 
  "detail-type": [
    "CodeBuild Build State Change"
  ],
  "detail": {
    "build-status": [
      "CLIENT_ERROR",
      "FAILED", 
      "FAULT",
      "STOPPED",
      "TIMED_OUT"
    ],
    "project-name": ["${var.activation_build_name}"]
  }  
}
EOF
}

resource "aws_cloudwatch_event_rule" "codebuild_deactivation" {
  name        = "codebuild_notify_deactivation_failures"
  description = "Send a notification when the CodeBuild lab deactivation build fails"
  tags        = var.tags

  event_pattern = <<EOF
{
  "source": [ 
    "aws.codebuild"
  ], 
  "detail-type": [
    "CodeBuild Build State Change"
  ],
  "detail": {
    "build-status": [
      "CLIENT_ERROR",
      "FAILED", 
      "FAULT",
      "STOPPED",
      "TIMED_OUT"
    ],
    "project-name": ["${var.deactivation_build_name}"]
  }  
}
EOF
}

resource "aws_cloudwatch_event_target" "lambda" {
  for_each = aws_cloudwatch_event_rule.lambda

  arn  = var.lab_status_topic_arn
  rule = each.value["id"]

  input_transformer {
    input_paths = {
      alarm_name     = "$.detail.alarmName",
      state          = "$.detail.state.value",
      previous_state = "$.detail.previousState.value",
    }
    input_template = "\"{\\\"sender\\\": \\\"${var.sender_email_address}\\\",\\\"admin\\\": \\\"${var.admin_email_address}\\\",\\\"activation\\\": false,\\\"message_type\\\": \\\"failure_message\\\",\\\"subject\\\": \\\"[Vending Machine] Lab Lambda alarm: <alarm_name>\\\",\\\"body\\\": \\\"An internal Lab Lambda Alarm has gone into an ALARM state. | State: <state> | Previous State: <previous_state> | Alarm name: <alarm_name>\\\"}\""
  }
}

resource "aws_cloudwatch_event_target" "codebuild_activation" {
  arn  = var.lab_status_topic_arn
  rule = aws_cloudwatch_event_rule.codebuild_activation.id

  input_transformer {
    input_paths = {
      status       = "$.detail.build-status",
      build_id     = "$.detail.build-id",
      project_name = "$.detail.project-name"
    }
    input_template = "\"{\\\"sender\\\": \\\"${var.sender_email_address}\\\",\\\"admin\\\": \\\"${var.admin_email_address}\\\",\\\"activation\\\": true,\\\"message_type\\\": \\\"failure_message\\\",\\\"subject\\\": \\\"[Vending Machine] Lab build failure: <project_name>\\\",\\\"body\\\": \\\"An internal Lab CodeBuild build has failed. | Project Name: <project_name> | Build ID: <build_id> | Status: <status>\\\"}\""
  }
}

resource "aws_cloudwatch_event_target" "codebuild_deactivation" {
  arn  = var.lab_status_topic_arn
  rule = aws_cloudwatch_event_rule.codebuild_deactivation.id

  input_transformer {
    input_paths = {
      status       = "$.detail.build-status",
      build_id     = "$.detail.build-id",
      project_name = "$.detail.project-name"
    }
    input_template = "\"{\\\"sender\\\": \\\"${var.sender_email_address}\\\",\\\"admin\\\": \\\"${var.admin_email_address}\\\",\\\"activation\\\": false,\\\"message_type\\\": \\\"failure_message\\\",\\\"subject\\\": \\\"[Vending Machine] Lab build failure: <project_name>\\\",\\\"body\\\": \\\"An internal Lab CodeBuild build has failed. | Project Name: <project_name> | Build ID: <build_id> | Status: <status>\\\"}\""
  }
}