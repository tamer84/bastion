
data "aws_iam_policy" "ssm" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role" "bastion_role" {
  name = "bastion_role_${terraform.workspace}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Terraform   = "true"
    Environment = terraform.workspace
  }
}

resource "aws_iam_role_policy" "bastion_role_policy" {
  name = "bastion_role_policy_${terraform.workspace}"
  role = aws_iam_role.bastion_role.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData",
                "ec2:DescribeVolumes",
                "ec2:DescribeTags",
                "logs:PutLogEvents",
                "logs:DescribeLogStreams",
                "logs:DescribeLogGroups",
                "logs:CreateLogStream",
                "logs:CreateLogGroup"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "${var.secret_arn}"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.bastion_role.name
  policy_arn = data.aws_iam_policy.ssm.arn
}

resource "aws_iam_instance_profile" "bastion_instance_profile" {
  name = "${terraform.workspace}_bastion_profile"
  role = aws_iam_role.bastion_role.name
}