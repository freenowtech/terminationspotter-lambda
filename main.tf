data "archive_file" "set_draining_state_zip" {
  type        = "zip"
  source_file = "${path.module}/set_draining_state.py"
  output_path = "${path.module}/set_draining_state.zip"
}

resource "aws_iam_role" "termination_notice_role" {
  name = "termination_notice_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "termination_notice_role_policy" {
  name = "termination_notice_role_policy"
  role = "${aws_iam_role.termination_notice_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "ecs:ListClusters",
                "ecs:ListContainerInstances",
                "ecs:DescribeContainerInstances",
                "ecs:UpdateContainerInstancesState"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_lambda_function" "set_draining_state" {
  function_name    = "termination_notice_set_draining_state"
  description      = "Sets ECS instance state to DRAINING "
  filename         = "${path.module}/set_draining_state.zip"
  role             = "${aws_iam_role.termination_notice_role.arn}"
  handler          = "set_draining_state.lambda_handler"
  timeout          = "5"
  source_code_hash = "${data.archive_file.set_draining_state_zip.output_base64sha256}"
  runtime          = "python3.6"
}

resource "aws_cloudwatch_event_rule" "event_rule" {
  name        = "termination_notice_events"
  description = "Triggers once there is a spot instance termination notice on the account"

  event_pattern = <<PATTERN
{
    "source": [
        "aws.ec2"
    ],
    "detail-type": [
        "EC2 Spot Instance Interruption Warning"
    ]
}
PATTERN
}

resource "aws_cloudwatch_event_target" "target" {
  rule = "${aws_cloudwatch_event_rule.event_rule.name}"
  arn  = "${aws_lambda_function.set_draining_state.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_set_draining_state" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.set_draining_state.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.event_rule.arn}"
}

resource "aws_sns_topic" "notification_topic" {
  name = "terminationspotter_notifications"
}

resource "aws_cloudwatch_event_target" "notification_target" {
  rule = "${aws_cloudwatch_event_rule.event_rule.name}"
  arn  = "${aws_sns_topic.notification_topic.arn}"
}
