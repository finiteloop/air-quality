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
    rh = float(result["humidity"]) if 'humidity' in result else None
    return model_pb2.Sensor(
        id=id,
        latitude=latitude,
        longitude=longitude,
        aqi_10m=aqi_from_pm(stats["v1"], rh),
        aqi_30m=aqi_from_pm(stats["v2"], rh),
        aqi_1h=aqi_from_pm(stats["v3"], rh),
        aqi_6h=aqi_from_pm(stats["v4"], rh),
        aqi_24h=aqi_from_pm(stats["v5"], rh),
        last_updated=int(stats["lastModified"]))


def aqi_from_pm(pm, rh=None):
    """Converts from PM2.5 to a standard AQI score.

    PM2.5 represents particulate matter <2.5 microns. We use the US standard
    for AQI.

    If a sensor isn't reporting humidity (rh), we can't apply the EPA correction;
    in that case, we use the uncorrected pm2.5
    """
    if rh is not None:
        corrected_pm = _apply_epa_correction(pm, rh)
    else:
        corrected_pm = pm
    if corrected_pm > 350.5:
        return _aqi(corrected_pm, 500, 401, 500, 350.5)
    elif corrected_pm > 250.5:
        return _aqi(corrected_pm, 400, 301, 350.4, 250.5)
    elif corrected_pm > 150.5:
        return _aqi(corrected_pm, 300, 201, 250.4, 150.5)
    elif corrected_pm > 55.5:
        return _aqi(corrected_pm, 200, 151, 150.4, 55.5)
    elif corrected_pm > 35.5:
        return _aqi(corrected_pm, 150, 101, 55.4, 35.5)
    elif corrected_pm > 12.1:
        return _aqi(corrected_pm, 100, 51, 35.4, 12.1)
    else:
        return _aqi(corrected_pm, 50, 0, 12, 0)


def _apply_epa_correction(pm, rh):
    """Applies the EPA calibration to Purple's PM2.5 data.
    Version of formula matches the Purple Air site's info.

    We floor it to 0 since the combination of very low pm2.5 concentration
    and very high humidity can lead to negative numbers.
    """
    return max(0, 0.534 * pm - 0.0844 * rh + 5.604)


def _aqi(pm, ih, il, bph, bpl):
    return round(((ih - il) / (bph - bpl)) * (pm - bpl) + il)
