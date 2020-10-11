# Copyright 2020 Bret Taylor

"""Invalidates CloudFront cache whenever our sensor data updates in S3."""

import boto3
import os
import time

def invalidate_cloudfront(distribution_id, paths):
    boto3.client("cloudfront").create_invalidation(
        DistributionId=distribution_id,
        InvalidationBatch={
            "Paths": {
                "Quantity": len(paths),
                "Items": paths,
            },
            "CallerReference": str(time.time())
        })

def lambda_handler(event, context):
    invalidate_cloudfront(
        distribution_id=os.environ["AWS_CLOUDFRONT_DISTRIBUTION_ID"],
        paths=["/" + r["s3"]["object"]["key"] for r in event["Records"]])
