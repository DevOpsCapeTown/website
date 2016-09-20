#!/bin/bash

set -e

[ -n "${TRAVIS_BRANCH}" ] && BRANCH="${TRAVIS_BRANCH}"

case "${BRANCH}" in
  production)
    DOMAIN="devops.capetown"
    ;;
  staging)
    DOMAIN="staging.devops.capetown"
    ;;
  *)
    echo No matching branch name, not deploying
    exit 0
esac

REGION="${AWS_DEFAULT_REGION}"
DIR="$(cd `dirname "$0"` && pwd)"

echo Create the S3 bucket
aws s3 ls "s3://${DOMAIN}" &> /dev/null || \
  (aws s3 mb "s3://${DOMAIN}" && sleep 5)

echo Set the bucket policy
! read -r -d '' S3_POLICY <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AddPerm",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${DOMAIN}/*"
    }
  ]
}
EOF
aws s3api put-bucket-policy --bucket "${DOMAIN}" --policy "${S3_POLICY}"

echo Configure static website
aws s3 website "s3://${DOMAIN}" --index-document index.html --error-document 404.html

echo Sync files
aws s3 sync --delete "${DIR}/_site/" "s3://${DOMAIN}/"

echo Create CloudFront distribution
! read -r -d '' CLOUDFRONT_CONFIG <<EOF
{
  "Aliases": {
    "Quantity": 1,
    "Items": ["${DOMAIN}"]
  },
  "CacheBehaviors": {
    "Quantity": 0
  },
  "CallerReference": "${DOMAIN}",
  "Comment": "DevOps Cape Town website (${BRANCH})",
  "CustomErrorResponses": {
    "Quantity": 0
  },
  "DefaultCacheBehavior": {
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": {
        "Quantity": 2,
        "Items": ["GET", "HEAD"]
      }
    },
    "Compress": true,
    "DefaultTTL": 60,
    "ForwardedValues": {
      "QueryString": true,
      "Cookies": {
        "Forward": "all",
        "WhitelistedNames": {
          "Quantity": 0
        }
      },
      "Headers": {
        "Quantity": 0
      }
    },
    "MaxTTL": 60,
    "MinTTL": 0,
    "SmoothStreaming": false,
    "TargetOriginId": "${DOMAIN}.s3-website-${REGION}.amazonaws.com",
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    },
    "ViewerProtocolPolicy": "redirect-to-https"
  },
  "DefaultRootObject": "index.html",
  "Enabled": true,
  "Logging": {
    "Enabled": true,
    "IncludeCookies": true,
    "Bucket": "devopscapetown-cloudfront.s3.amazonaws.com",
    "Prefix": "${DOMAIN}"
  },
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "${DOMAIN}.s3-website-${REGION}.amazonaws.com",
        "DomainName": "${DOMAIN}.s3-website-${REGION}.amazonaws.com",
        "OriginPath": "",
        "CustomHeaders": {
          "Quantity": 0
        },
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only",
          "OriginSslProtocols": {
            "Quantity": 3,
            "Items": ["TLSv1", "TLSv1.1", "TLSv1.2"]
          }
        }
      }
    ]
  },
  "PriceClass": "PriceClass_All",
  "ViewerCertificate": {
    "ACMCertificateArn": "${AWS_CERTIFICATE_ARN}",
    "CertificateSource": "acm",
    "MinimumProtocolVersion": "TLSv1",
    "SSLSupportMethod": "sni-only"
  },
  "WebACLId": ""
}
EOF
aws configure set preview.cloudfront true
[ -z "$(aws cloudfront list-distributions | jq -r ".DistributionList.Items[] | select(.Aliases.Items[] == \"${DOMAIN}\")")" ] && \
  aws cloudfront create-distribution --distribution-config "${CLOUDFRONT_CONFIG}"

echo Create DNS record
! read -r -d '' ROUTE53_CHANGES <<EOF
{
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "${DOMAIN}",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "$(aws cloudfront list-distributions | jq -r ".DistributionList.Items[] | select(.Aliases.Items[] == \"${DOMAIN}\") | .DomainName")",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
EOF
aws route53 change-resource-record-sets --hosted-zone-id "${AWS_HOSTED_ZONE_ID}" --change-batch "${ROUTE53_CHANGES}"

# vim: set ts=2 sts=2 sw=2 et:
