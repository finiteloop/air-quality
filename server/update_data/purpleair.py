# Copyright 2020 Bret Taylor

"""Converts between PurpleAir JSON data and our proprietary protocol buffers."""

import json
import model_pb2

JSON_URL = "https://www.purpleair.com/json"


def parse_json(data):
    """Parses the PupleAir JSON file, returning a Sensors protobuf."""
    channel_a = []
    channel_b = {}
    for result in data["results"]:
        if "ParentID" in result:
            channel_b[result["ParentID"]] = result
        else:
            channel_a.append(result)
    sensors = list(_parse_results(channel_a, channel_b))
    return model_pb2.Sensors(sensors=sensors)


def compact_sensor_data(sensors):
    """Returns a new set of Sensors with minimal sensor data (lat, lng, aqi).

    We use this reduced payload for the Widget, which does not need details like
    the sensor ID or 24-hour AQI average.
    """
    compact = []
    for sensor in sensors.sensors:
        compact.append(model_pb2.Sensor(
            id=sensor.id,
            latitude=sensor.latitude,
            longitude=sensor.longitude,
            aqi_10m=sensor.aqi_10m))
    return model_pb2.Sensors(sensors=compact)


def _valid_result(result):
    if result.get("DEVICE_LOCATIONTYPE", "outside") != "outside":
        # Skip sensors that are inside
        return False
    elif int(result["AGE"]) > 300:
        # Ignore device readings more than 5 minutes old
        return False
    return "Lat" in result and "Lon" in result and "Stats" in result


def _parse_results(channel_a, channel_b):
    for result in channel_a:
        assert "ParentID" not in result
        if not _valid_result(result):
            continue
        elif result.get("Flag"):
            # PurpleAir has flagged this sensor for unusually high readings.
            # Fall back to channel B if its result has not been flagged.
            result_b = channel_b.get(result["ID"])
            if result_b and _valid_result(result_b) and not result_b.get("Flag"):
                yield _parse_result(result_b)
        else:
            yield _parse_result(result)


def _parse_result(result):
    id = int(result["ID"])
    latitude = float(result["Lat"])
    longitude = float(result["Lon"])
    stats = json.loads(result["Stats"])
    return model_pb2.Sensor(
        id=id,
        latitude=latitude,
        longitude=longitude,
        aqi_10m=aqi_from_pm(stats["v1"]),
        aqi_30m=aqi_from_pm(stats["v2"]),
        aqi_1h=aqi_from_pm(stats["v3"]),
        aqi_6h=aqi_from_pm(stats["v4"]),
        aqi_24h=aqi_from_pm(stats["v5"]),
        last_updated=int(stats["lastModified"]))


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
