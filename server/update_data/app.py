# Copyright 2020 Bret Taylor

"""A Lambda function that runs periodically to update PurpleAir sensor data."""

import boto3
import json
import logging
import os
import purpleair
import time
import urllib.request


def update_sensor_data(s3_bucket, s3_object):
    """Uploads PurpleAir sensor data to the location used by our clients.

    We download JSON from PurpleAir and convert to our proprietary Protocol
    Buffer format, which is used by all clients. We upload a single file for
    the world, which, due to reducing the data per sensor and the efficiency of
    protocol buffers, is below 400KB uncompressed and significantly less when
    compressed.
    """
    start_time = time.time()
    raw = urllib.request.urlopen(purpleair.JSON_URL).read()
    download_time = time.time()
    sensors = purpleair.parse_json(json.loads(raw))
    parse_time = time.time()
    s3 = boto3.client("s3")
    s3.put_object(
        Bucket=s3_bucket,
        Key=s3_object,
        Body=sensors.SerializeToString(),
        ACL="public-read",
        ContentType="application/protobuf")
    s3_time = time.time()
    total_time = time.time() - start_time
    logging.info("Processed PurpleAir in %.1fs (download: %.1fs, parse: %.1fs, "
        "s3: %.1fs)", total_time, download_time - start_time,
        parse_time - download_time, s3_time - parse_time)


def lambda_handler(event, context):
    update_sensor_data(
        s3_bucket=os.environ["AWS_S3_BUCKET"],
        s3_object=os.environ["AWS_S3_OBJECT"])
