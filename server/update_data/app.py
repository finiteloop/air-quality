# Copyright 2020 Bret Taylor

"""A Lambda function that runs periodically to update PurpleAir sensor data."""

import boto3
import json
import logging
import os
import purpleair
import time
import urllib.request


def update_sensor_data(s3_bucket, s3_object, compact_s3_object):
    """Uploads PurpleAir sensor data to the location used by our clients.

    We download JSON from PurpleAir and convert to our proprietary Protocol
    Buffer format, which is used by all clients.

    We upload two versions of the protocol buffer data: complete data, used by
    the app to display AQI readings and 24-hour averages; and compact data,
    which just contains a single reading, is used by the widget.
    """
    start_time = time.time()
    raw = urllib.request.urlopen(purpleair.JSON_URL).read()
    download_time = time.time()
    sensors = purpleair.parse_json(json.loads(raw))
    compact = purpleair.compact_sensor_data(sensors)
    parse_time = time.time()
    s3 = boto3.client("s3")
    s3.put_object(
        Bucket=s3_bucket,
        Key=s3_object,
        Body=sensors.SerializeToString(),
        ACL="public-read",
        ContentType="application/protobuf")
    s3.put_object(
        Bucket=s3_bucket,
        Key=compact_s3_object,
        Body=compact.SerializeToString(),
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
        s3_object=os.environ["AWS_S3_OBJECT"],
        compact_s3_object=os.environ["AWS_S3_OBJECT_COMPACT"])
