# Copyright 2020 Bret Taylor

"""Converts between PurpleAir JSON data and our proprietary protocol buffers."""

import json
import model_pb2

JSON_URL = "https://www.purpleair.com/json"


def parse_json(data):
    """Parses the PupleAir JSON file, returning a Sensors protobuf."""
    sensors = []
    for result in data["results"]:
        try:
            sensor = _parse_result(result)
        except:
            continue
        sensors.append(sensor)
    return model_pb2.Sensors(sensors=sensors)


def _parse_result(result):
    if result.get("DEVICE_LOCATIONTYPE", "outside") != "outside":
        # Skip sensors that are inside
        raise Exception("Device is not outside")
    if int(result["AGE"]) > 300:
        # Ignore device readings more than 5 minutes old
        raise Exception("Device reading is outdated")
    id = int(result["ID"])
    latitude = float(result["Lat"])
    longitude = float(result["Lon"])
    if result.get("humidity", "none") != "outside":
        # Skip sensors that do not have humiditiy
        raise Exception("Device has no humiditiy reading")
    humidity = int(result["humidity"])
    stats = json.loads(result["Stats"])
    reading = aqi_from_pm(stats["v1"], humidity)
    return model_pb2.Sensor(
        id=id, latitude=latitude, longitude=longitude, reading=reading)


def aqi_from_pm(raw_pm, humidity):
    """Converts from PM2.5 to a standard AQI score.
    
    PM2.5 represents particulate matter <2.5 microns. We use the US standard
    for AQI.
    """

    # See https://cfpub.epa.gov/si/si_public_record_report.cfm?dirEntryId=349513&Lab=CEMM for formula
    pm = 0.534 * raw_pm - 0.0844 * humidity + 5.604

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
