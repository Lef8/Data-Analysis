import pandas as pd
import matplotlib.pyplot as plt
import numpy as np

from sklearn.cluster import KMeans
from sklearn.preprocessing import StandardScaler
from matplotlib.ticker import FuncFormatter

# --- import data ---
# read
df_cities = pd.read_csv(".\\exported_data\\cities_by_trans_per_person.csv")
df_holders = pd.read_csv(".\\exported_data\\pid_gender_age_mostfreqcity_sumtrans.csv")

# add column to holders df with percentile of city
# where 0=top, 1=bottom
_cities = df_cities["merchant_city"]
_city_index = lambda city: _cities[_cities == city].index[0]

city_perc = lambda city: _city_index(city) / _cities.shape[0]
apply_city_perc_on_row = lambda row: city_perc(row["merchant_city"])

df_holders["city_perc"] = df_holders.apply(apply_city_perc_on_row, axis=1)

# add gender_binary
gender_to_binary = lambda row: 0 if row["gender"] == "M" else 1
df_holders["gender_binary"] = df_holders.apply(gender_to_binary, axis=1)

# extract and standardize features
features = ["age", "city_perc", "transaction_amount"]
x = df_holders[features]
scaler = StandardScaler()
x_scaled = scaler.fit_transform(x)
 
# --- do kmeans ---
num_clusters = 5
kmeans = KMeans(n_clusters=num_clusters, random_state=42)
kmeans.fit(x_scaled)

# Get cluster centroids and labels
centroids = kmeans.cluster_centers_
centroids_unscaled = scaler.inverse_transform(centroids)
df_centroids = pd.DataFrame(centroids_unscaled, columns=features)
labels = kmeans.labels_

# Add cluster labels to the original DataFrame
df_holders['cluster'] = labels

# Print cluster centroids
print("Cluster Centroids:")
print(df_centroids)

# --- visualise ---
x_axis = "age"
y_axis = "transaction_amount"
size = "city_perc"
color = "cluster"

fig = plt.figure()
ax = fig.add_subplot(111)
ax.yaxis.set_major_formatter(
    FuncFormatter(lambda x, p: f"{int(x)/1000000}M"))

plt.scatter(
    x=df_holders[x_axis], y=df_holders[y_axis],
    c=df_holders[color], s=df_holders[size] * 200,
    marker='o',
)

plt.scatter(
    x=df_centroids[x_axis], y=df_centroids[y_axis],
    c="red", s=100, marker='x',
)

# Make sure x- and y-labels match the x- and y-axes above
plt.xlabel("Age")
plt.ylabel("Transactions Sum")
plt.title("Cluster Holders by Age, Transaction Sum and City Percentile")
plt.grid(True)
plt.show()

unique, counts = np.unique(df_holders['cluster'], return_counts=True)
print({u:c for u, c in zip(unique, counts)})
print({u:round(c, 2) for u, c in zip(unique, counts / sum(counts))})
print(df_centroids)
