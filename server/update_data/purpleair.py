# Copyright 2020 Bret Taylor

"""Converts between PurpleAir JSON data and our proprietary protocol buffers."""

import json
import model_pb2

JSON_URL = "https://www.purpleair.com/json"


def parse_json(data):
    """Parses the PupleAir JSON file, returning a Sensors protobuf."""
    all_results = data["results"]
    filtered_results = _filter_results(all_results)

    channel_b_dict = _channel_b_dict(all_results)
    fallback_results = _fallback_to_channel_b(filtered_results, channel_b_dict)

    sensors = _parse_results(fallback_results)

    return model_pb2.Sensors(sensors=sensors)


def _filter_results(results):
    return [r for r in results if _filter_result(r)]


def _filter_result(result):
    """Returns True/False whether a single API result should be included in the dataset"""
    if result.get("ParentID"):
        # Channel B is a redundant sensor on the same physical device
        return False
    elif result.get("DEVICE_LOCATIONTYPE", "outside") != "outside":
        # Skip sensors that are inside
        return False
    elif int(result["AGE"]) > 300:
        # Ignore device readings more than 5 minutes old
        return False
    return True


def _channel_b_dict(results):
    """Constructs a dictionary mapping Channel A (primary) IDs to Channel B
    (secondary) results."""
    return {r["ParentID"]:r for r in results if r.get("ParentID")}


def _fallback_to_channel_b(channel_a_results, channel_b_dict):
    """Fallback to the Channel B result if Channel A has a bad reading"""
    fallback_results = []
    for channel_a_result in channel_a_results:
        if _good_reading(channel_a_result):
            fallback_results.append(channel_a_result)
        else:
            channel_b_result = channel_b_dict.get(channel_a_result["ID"])
            if _good_reading(channel_b_result):
                fallback_results.append(channel_b_result)
    return fallback_results


def _good_reading(result):
    # Flag: 1 means the device has been flagged for unusally high readings
    return not result.get("Flag")


def _parse_results(results):
    sensors = []
    for result in results:
        try:
            sensor = _parse_result(result)
        except:
            continue
        sensors.append(sensor)
    return sensors


def _parse_result(result):
    """Parses a single API result into a Sensor protobuf"""
    id = int(result["ID"])
    latitude = float(result["Lat"])
    longitude = float(result["Lon"])
    stats = json.loads(result["Stats"])
    reading = aqi_from_pm(stats["v1"])
    return model_pb2.Sensor(
        id=id, latitude=latitude, longitude=longitude, reading=reading)


def aqi_from_pm(pm):
    """Converts from PM2.5 to a standard AQI score.

    PM2.5 represents particulate matter <2.5 microns. We use the US standard
    for AQI.
    """
    if pm > 350.5:
        return _aqi(pm, 500, 401, 500, 350.5)
    elif pm > 250.5:
        return _aqi(pm, 400, 301, 350.4, 250.5)
    elif pm > 150.5:
        return _aqi(pm, 300, 201, 250.4, 150.5)
    elif pm > 55.5:
        return _aqi(pm, 200, 151, 150.4, 55.5)
    elif pm > 35.5:
        return _aqi(pm, 150, 101, 55.4, 35.5)
    elif pm > 12.1:
        return _aqi(pm, 100, 51, 35.4, 12.1)
    else:
        return _aqi(pm, 50, 0, 12, 0)


def _aqi(pm, ih, il, bph, bpl):
    return round(((ih - il) / (bph - bpl)) * (pm - bpl) + il)
