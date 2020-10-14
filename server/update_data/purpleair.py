# Copyright 2020 Bret Taylor

"""Converts between PurpleAir JSON data and our proprietary protocol buffers."""

import json
import model_pb2

JSON_URL = "https://www.purpleair.com/json"


def parse_json(data):
    """Parses the PupleAir JSON file, returning a Sensors protobuf."""
    all_results = data["results"]
    filtered_results = _filter_results(all_results)

    sensors = _parse_results(filtered_results)

    return model_pb2.Sensors(sensors=sensors)


def _filter_results(results):
    return [r for r in results if _filter_result(r)]


def _filter_result(result):
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
