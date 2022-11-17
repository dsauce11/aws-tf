terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

/* AWS S3 Bucket source and Versioning must be
turned on

added to it is the replication configuration
*/

provider "aws" {
  //profile = "default"
  alias = "east"
  region  = "us-east-2"
}

resource "aws_s3_bucket" "demo-bucket"{
  provider = aws.east  
  bucket = "to-copy-demo-bucket"
  acl = "private"

  versioning {
    enabled = true
  }

  tags = {
    Name = "S3Bucket"
  }

  replication_configuration {
    role = "${aws_iam_role.my-replication-role.arn}"

    rules {
        prefix = ""
        status = "Enabled"

        destination {
            bucket        = "${aws_s3_bucket.demo-destination.arn}"
            storage_class = "STANDARD"
        }
    }
  }
}

// AWS replicate to

provider "aws" {
    region = "us-east-1"
}

resource "aws_s3_bucket" "demo-destination" {
    bucket = "to-send-destination-bucket"
    acl = "private"

    versioning {
    enabled = true
  }

  tags = {
    Name = "S3Bucket"
  }
  
}

// AWS IAM Role creation

resource "aws_iam_role" "my-replication-role" {
    name = "my-replication-role"

    assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "s3.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
POLICY
}


// AWS IAM Role Policy 
resource "aws_iam_policy" "my-replication-policy" {
  name = "my-replication-policy"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.demo-bucket.arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersion",
        "s3:GetObjectVersionAcl"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.demo-bucket.arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.demo-destination.arn}/*"
    }
  ]
}
POLICY
}

resource "aws_iam_policy_attachment" "replication" {
  name       = "demo-IAM-Replication"
  roles      = ["${aws_iam_role.my-replication-role.name}"]
  policy_arn = "${aws_iam_policy.my-replication-policy.arn}"
}