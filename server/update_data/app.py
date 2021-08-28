# Copyright 2020 Bret Taylor

"""A Lambda function that runs periodically to update PurpleAir sensor data."""

import boto3
import logging
import os
import purpleair
import time
import urllib.request


def update_sensor_data(
    purpleair_api_key, s3_bucket, s3_object, raw_s3_object, compact_s3_object):
    """Uploads PurpleAir sensor data to the location used by our clients.

    We download JSON from PurpleAir and convert to our proprietary Protocol
    Buffer format, which is used by all clients.

    We upload three versions of the protocol buffer data:
      (1) The corrected EPA AQI readings
      (2) Raw PurpleAir PM2.5 AQI readings
      (3) A compact data, with just a single AQI reading, used by the widget
    """
    start_time = time.time()
    raw = urllib.request.urlopen(purpleair.api_url(purpleair_api_key)).read()
    download_time = time.time()
    data = purpleair.parse_api(raw, epa_correction=True)
    raw_data = purpleair.parse_api(raw, epa_correction=False)
    compact_data = purpleair.compact_sensor_data(data)
    parse_time = time.time()
    s3 = boto3.client("s3")
    update(s3, s3_bucket, data=data, object_name=s3_object)
    update(s3, s3_bucket, data=compact_data, object_name=compact_s3_object)
    update(s3, s3_bucket, data=raw_data, object_name=raw_s3_object)
    s3_time = time.time()
    total_time = time.time() - start_time
    logging.info("Processed PurpleAir in %.1fs (download: %.1fs, parse: %.1fs, "
        "s3: %.1fs)", total_time, download_time - start_time,
        parse_time - download_time, s3_time - parse_time)


def update(s3, bucket, data, object_name):
    s3.put_object(
        Bucket=bucket,
        Key=object_name,
        Body=data.SerializeToString(),
        ACL="public-read",
        ContentType="application/protobuf")


def lambda_handler(event, context):
    update_sensor_data(
        purpleair_api_key=os.environ["PURPLEAIR_API_KEY"],
        s3_bucket=os.environ["AWS_S3_BUCKET"],
        s3_object=os.environ["AWS_S3_OBJECT"],
        raw_s3_object=os.environ["AWS_S3_OBJECT_RAW"],
        compact_s3_object=os.environ["AWS_S3_OBJECT_COMPACT"])
