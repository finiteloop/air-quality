# pytest file
# best invoked from the server/ directory as pytest tests/
import sys
import pytest
from pathlib import Path
sys.path.append(str(Path(__file__).parents[1] / "update_data/"))
from purpleair import _apply_epa_correction, aqi_from_pm

def test_zero_pm25():
    corrected = _apply_epa_correction(0, 80)
    assert corrected == 0
    raw_aqi = aqi_from_pm(corrected)
    assert raw_aqi == 0

def test_basic_correction():
    input = 16.76
    # no correction applied, since no humidity reading given
    raw_aqi = aqi_from_pm(input, rh=None)
    assert raw_aqi == 61
    output = _apply_epa_correction(input, rh=14)
    assert output == pytest.approx(13.37224)
    corrected_aqi = aqi_from_pm(output)
    assert corrected_aqi == 54
    # finally, test that passing in rh to the overall aqi_from_pm leads to same result
    corrected_from_fn = aqi_from_pm(input, rh=14)
    assert corrected_aqi == corrected_from_fn

def test_zero_humidity():
    input = 16.76
    output = _apply_epa_correction(input, 0)
    corrected_aqi = aqi_from_pm(output)
    assert corrected_aqi == 56