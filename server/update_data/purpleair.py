# Copyright 2020 Bret Taylor

"""Converts between PurpleAir JSON data and our proprietary protocol buffers."""

import json
import model_pb2
import urllib.parse

JSON_URL = "https://www.purpleair.com/json"
API_URL = "https://api.purpleair.com/v1/sensors"

_API_FIELDS = [
    "sensor_index",
    "latitude",
    "longitude",
    "humidity",
    "pm2.5_10minute",
    "pm2.5_30minute",
    "pm2.5_60minute",
    "pm2.5_6hour",
    "pm2.5_24hour",
    "last_seen",
]


def api_url(api_key):
    """Returns the download URL for the PurpleAir API with the given API key."""
    return API_URL + "?" + urllib.parse.urlencode({
        "api_key": api_key,
        "max_age": 300,      # Filter out sensors that have stopped updating
        "location_type": 0,  # Outside sensors only
        "fields": ",".join(_API_FIELDS)
    })


def parse_api(data, epa_correction=True):
    """Parses the response from the PurpleAIR API (https://api.purpleair.com).

    We return a Sensors protobuf suitable for the Air Quality app clients.

    If epa_correction is True, we correct the readings to more closely match
    EPA AQI standards.
    """
    response = json.loads(data)
    field_indexes = {n: response["fields"].index(n) for n in _API_FIELDS}
    pm_fields = [
        "pm2.5_10minute",
        "pm2.5_30minute",
        "pm2.5_60minute",
        "pm2.5_6hour",
        "pm2.5_24hour",
    ]
    sensors = []
    for item in response["data"]:
        humidity = item[field_indexes["humidity"]]
        latitude = item[field_indexes["latitude"]]
        longitude = item[field_indexes["longitude"]]
        if not latitude or not longitude:
            continue
        has_pm_data = True
        for pm_field in pm_fields:
            if not item[field_indexes[pm_field]]:
                has_pm_data = False
                break
        if not has_pm_data:
            continue
        sensors.append(model_pb2.Sensor(
            id=item[field_indexes["sensor_index"]],
            latitude=latitude,
            longitude=longitude,
            aqi_10m=aqi_from_pm(item[field_indexes["pm2.5_10minute"]], humidity, epa_correction),
            aqi_30m=aqi_from_pm(item[field_indexes["pm2.5_30minute"]], humidity, epa_correction),
            aqi_1h=aqi_from_pm(item[field_indexes["pm2.5_60minute"]], humidity, epa_correction),
            aqi_6h=aqi_from_pm(item[field_indexes["pm2.5_6hour"]], humidity, epa_correction),
            aqi_24h=aqi_from_pm(item[field_indexes["pm2.5_24hour"]], humidity, epa_correction),
            last_updated=item[field_indexes["last_seen"]] * 1000))
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


def aqi_from_pm(pm, rh=None, epa_correction=True):
    """Converts from PM2.5 to a standard AQI score.

    PM2.5 represents particulate matter <2.5 microns. We use the US standard
    for AQI.

    If a sensor isn't reporting humidity (rh), we can't apply the EPA correction;
    in that case, we use the uncorrected pm2.5.

    See https://cfpub.epa.gov/si/si_public_record_report.cfm?Lab=CEMM&dirEntryId=348236
    for details on the EPA correction formula.
    """
    if rh is not None and epa_correction:
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

    We floor it to 0 since the combination of very low pm2.5 concentration
    and very high humidity can lead to negative numbers.
    """
    return max(0, 0.534 * pm - 0.0844 * rh + 5.604)


def _aqi(pm, ih, il, bph, bpl):
    return round(((ih - il) / (bph - bpl)) * (pm - bpl) + il)
