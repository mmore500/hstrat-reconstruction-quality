import numpy as np
import pandas as pd

from pylib._styler_to_pdf import styler_to_pdf


def test_styler_to_pdf():
    # adapted from https://pandas.pydata.org/pandas-docs/stable/reference/api/pandas.io.formats.style.Styler.html
    weather_df = pd.DataFrame(
        np.random.rand(10, 2) * 5,
        index=pd.date_range(start="2021-01-01", periods=10),
        columns=["Tokyo", "Beijing"],
    )

    def rain_condition(v):
        if v < 1.75:
            return "Dry"
        elif v < 2.75:
            return "Rain"
        return "Heavy Rain"

    def make_pretty(styler):
        styler.set_caption("Weather Conditions")
        styler.format(rain_condition)
        styler.format_index(lambda v: v.strftime("%A"))
        styler.background_gradient(axis=None, vmin=1, vmax=5, cmap="YlGnBu")
        return styler

    styler = weather_df.loc["2021-01-04":"2021-01-08"].style.pipe(make_pretty)
    styler_to_pdf(styler, "/tmp/styler_to_pdf-weather.pdf")
