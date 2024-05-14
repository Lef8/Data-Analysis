# source: https://vitalflux.com/autoregressive-ar-models-with-python-examples/

from statsmodels.graphics.tsaplots import plot_pacf
from statsmodels.tsa.ar_model import AutoReg

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.ticker import FuncFormatter

# --- read ---
df = pd.read_csv("./exported_data/sum_transaction_timeseries.csv")
train = df["sum_amount"][:60]

# --- do stat: fit ---
# perform pacf to find lags to use
pacf = plot_pacf(train, lags=25, method="ywm")
# pacf.show() # <-- uncomment to show pacf plot

# fit an auto-regressive model with the lags found from pacf
lags = [6, 11, 12]
ar_model = AutoReg(train, lags=lags, trend="c")
fitted_ar_model = ar_model.fit()
print(f"{lags=}")
print(fitted_ar_model.summary())

# notice that the p-value for sum_amount.L6, sum_amount.L11 is very large
lags = [12]
ar_model = AutoReg(train, lags=lags, trend="c")
fitted_ar_model = ar_model.fit()
print(f"{lags=}")
print(fitted_ar_model.summary())

# notice that the p-value for constant is very large
lags = [12]
ar_model = AutoReg(train, lags=lags, trend="n")
fitted_ar_model = ar_model.fit()
print(f"{lags=}")
print(fitted_ar_model.summary())

# all p-values are acceptable at confidence level a=0.05

# --- do stat: predict ---
train_months = len(train)
extra_months_to_predict = 24 + 1

pred_train = fitted_ar_model.predict(start=0, end=train_months - 1)
pred_new = fitted_ar_model.predict(start=train_months, end=train_months + extra_months_to_predict)

# --- visualise ---
fig = plt.figure()
ax = fig.add_subplot(111)
ax.yaxis.set_major_formatter(
    FuncFormatter(lambda x, p: f"{int(x)/1000000}M"))
ax.plot(train, color="green", label="Ground Truth")
ax.plot(pred_train, color="orange", label="Validation")
ax.plot(pred_new, color="magenta", label="Forecast")
ticks = np.arange(0, train_months + extra_months_to_predict, 12)
plt.xticks(ticks, [f"Jan.\n{2015 + tick//12}" for tick in ticks])
plt.grid(True, which="major", axis="x")
plt.title("Total Expenditures per Month")
plt.legend()
plt.show()
