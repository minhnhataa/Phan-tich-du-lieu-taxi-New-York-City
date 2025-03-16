<h1 align="center">PHÂN TÍCH DỮ LIỆU CHUYẾN ĐI TAXI NYC</h1>

<div align="center">

<p align="center">
  <img src="logo.png" alt="DaiNam University Logo" width="200"/>
</p>


[![Fit DNU](https://img.shields.io/badge/Fit%20DNU-green?style=for-the-badge)](https://fitdnu.net/)
[![DaiNam University](https://img.shields.io/badge/DaiNam%20University-red?style=for-the-badge)](https://dainam.edu.vn)

</div>

<h2 align="center">PHÂN TÍCH DỮ LIỆU CHUYẾN ĐI TAXI NYC</h2>

# 📊 Phân Tích Dữ Liệu Chuyến Đi Taxi NYC

## 🚀 Giới Thiệu

Dự án này sử dụng **R**, **Spark**, và **ggplot2** để phân tích dữ liệu chuyến đi taxi tại thành phố New York. Mục tiêu chính của dự án:

- Xử lý dữ liệu taxi lớn bằng Spark để tối ưu hiệu suất.
- Phân tích số lượng chuyến đi theo ngày, giờ và ngày trong tuần.
- Trực quan hóa xu hướng chuyến đi bằng biểu đồ.
- Xây dựng mô hình hồi quy tuyến tính để dự đoán tổng chi phí chuyến đi.


---

## 🛠️ Công Nghệ Sử Dụng

### 📡 Phần mềm & Thư viện

[![R](https://img.shields.io/badge/R-4.x-blue?style=for-the-badge&logo=r)](https://www.r-project.org/)
[![Spark](https://img.shields.io/badge/Spark-3.x-orange?style=for-the-badge&logo=apache-spark)](https://spark.apache.org/)
[![ggplot2](https://img.shields.io/badge/ggplot2-Visualization-green?style=for-the-badge)](https://ggplot2.tidyverse.org/)

Dự án sử dụng các thư viện chính:

```r
install.packages("sparklyr")
install.packages("dplyr")
install.packages("ggplot2")
install.packages("lubridate")
```

---

## 🔌 Yêu Cầu Hệ Thống

- **Hệ điều hành**: Windows/Linux/MacOS
- **R version**: 4.x
- **Apache Spark**: 3.x
- **RAM tối thiểu**: 8GB

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy

### 1️⃣ Thiết Lập Môi Trường Spark
```r
library(sparklyr)
sc <- spark_connect(master = "local")
```

### 2️⃣ Đọc Dữ Liệu Từ CSV
```r
taxi_data <- spark_read_csv(
  sc,
  name = "taxi_data",
  path = "data/yellow_tripdata_2015-01_lam_sach.csv",
  infer_schema = TRUE,
  header = TRUE,
  repartition = 10
)
```

### 3️⃣ Xử Lý Dữ Liệu
```r
taxi_data <- taxi_data %>%
  mutate(
    tpep_pickup_datetime = to_timestamp(tpep_pickup_datetime, "yyyy-MM-dd HH:mm:ss"),
    tpep_dropoff_datetime = to_timestamp(tpep_dropoff_datetime, "yyyy-MM-dd HH:mm:ss"),
    trip_duration = (unix_timestamp(tpep_dropoff_datetime) - unix_timestamp(tpep_pickup_datetime)) / 60
  ) %>%
  filter(trip_duration > 0 & trip_duration < 1440)
```

### 4️⃣ Trực Quan Hóa Dữ Liệu
```r
ggplot(daily_trips, aes(x = pickup_day, y = total_trips)) +
  geom_line(color = "blue", linewidth = 1) +
  labs(title = "Xu hướng số lượng chuyến đi theo ngày", x = "Ngày", y = "Số lượng chuyến đi") +
  theme_minimal()
```

### 5️⃣ Xây Dựng Mô Hình Hồi Quy Tuyến Tính
```r
model <- lm(total_fare ~ trip_duration + trip_distance + pickup_hour + pickup_weekday, data = model_data)
summary(model)
```

---

## 📊 Kết Quả Phân Tích

### 🔹 Xu hướng số lượng chuyến đi theo ngày
📈 Biểu đồ cho thấy sự thay đổi số lượng chuyến đi theo ngày trong tháng.

### 🔹 Sự phân bố giá cước (Fare Amount)
📊 Histogram hiển thị phân phối giá cước với nhiều chuyến đi có mức giá thấp.

### 🔹 Mô hình dự đoán chi phí chuyến đi
📉 Mô hình hồi quy tuyến tính giúp dự đoán tổng chi phí chuyến đi dựa trên thời gian, khoảng cách và thời điểm trong ngày.

---

## 🤝 Đóng Góp
Hoàng Mạnh Linh CNTT16-03