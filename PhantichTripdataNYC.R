library(sparklyr)
library(dplyr)
library(ggplot2)
library(lubridate) # Bổ sung thư viện để xử lý thời gian

# Kết nối Spark
sc <- spark_connect(master = "local")
spark_web(sc)

# Đọc dữ liệu với tối ưu hóa cho dữ liệu lớn
taxi_data <- spark_read_csv(
  sc,
  name = "taxi_data",
  path = "C:/Du_lieu_lon/yellow_tripdata_2015-01_lam_sach.csv",
  infer_schema = TRUE,
  header = TRUE,
  repartition = 10  # Điều chỉnh số lượng phân vùng khi đọc dữ liệu lớn
)

# Xử lý các cột thời gian và thêm cột mới, tính toán trip_duration
taxi_data <- taxi_data %>%
  mutate(
    store_and_fwd_flag = ifelse(store_and_fwd_flag == "N", 0, 1),
    tpep_pickup_datetime = to_timestamp(tpep_pickup_datetime, "yyyy-MM-dd HH:mm:ss"),
    tpep_dropoff_datetime = to_timestamp(tpep_dropoff_datetime, "yyyy-MM-dd HH:mm:ss"),
    trip_duration = (unix_timestamp(tpep_dropoff_datetime) - unix_timestamp(tpep_pickup_datetime)) / 60
  ) %>%
  filter(
    !is.na(tpep_pickup_datetime),
    !is.na(tpep_dropoff_datetime),
    trip_duration > 0 & trip_duration < 1440,  # Chỉ lọc những chuyến đi có thời gian hợp lý
    fare_amount > 0,
    trip_distance > 0,
    fare_amount < 500, # Loại bỏ ngoại lệ
    trip_distance < 100 # Loại bỏ khoảng cách bất hợp lý
  )

# Kiểm tra và thêm cột surcharge nếu không tồn tại
if (!("surcharge" %in% colnames(taxi_data))) {
  taxi_data <- taxi_data %>%
    mutate(surcharge = 0) # Thêm cột surcharge với giá trị mặc định là 0
}

# Tính toán lại tổng chi phí
taxi_data <- taxi_data %>%
  mutate(
    total_fare = fare_amount + tolls_amount + extra + surcharge,
    pickup_day = day(tpep_pickup_datetime),
    pickup_weekday = date_format(tpep_pickup_datetime, "EEEE"),  # Thay thế wday()
    pickup_hour = hour(tpep_pickup_datetime),
    pickup_hour_group = case_when(
      pickup_hour %in% c(7, 8, 9, 17, 18, 19) ~ "peak",
      TRUE ~ "off_peak"
    )
  )

# Nhóm dữ liệu và tính toán chỉ số tổng hợp theo ngày, giờ, và ngày trong tuần
daily_trips <- taxi_data %>%
  group_by(pickup_day) %>%
  summarize(
    total_trips = n(),
    avg_fare = mean(total_fare, na.rm = TRUE),
    avg_duration = mean(trip_duration, na.rm = TRUE)
  ) %>%
  arrange(pickup_day)

hourly_trips <- taxi_data %>%
  group_by(pickup_hour) %>%
  summarize(
    total_trips = n(),
    avg_fare = mean(total_fare, na.rm = TRUE),
    avg_duration = mean(trip_duration, na.rm = TRUE)
  ) %>%
  arrange(pickup_hour)

weekday_trips <- taxi_data %>%
  group_by(pickup_weekday) %>%
  summarize(
    total_trips = n(),
    avg_fare = mean(total_fare, na.rm = TRUE),
    avg_duration = mean(trip_duration, na.rm = TRUE)
  )

# Chuẩn hóa thứ tự ngày trong tuần
weekday_trips_local <- collect(weekday_trips) %>%
  mutate(
    pickup_weekday = factor(pickup_weekday, 
                            levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"))
  )

# Trực quan hóa xu hướng chuyến đi
ggplot(daily_trips, aes(x = pickup_day, y = total_trips)) +
  geom_line(color = "blue", linewidth = 1) + # Sửa lỗi size -> linewidth
  labs(
    title = "Xu hướng số lượng chuyến đi theo ngày trong tháng",
    x = "Ngày trong tháng",
    y = "Số lượng chuyến đi"
  ) +
  theme_minimal()

ggplot(hourly_trips, aes(x = pickup_hour, y = total_trips)) +
  geom_line(color = "green", linewidth = 1) +
  labs(
    title = "Xu hướng số lượng chuyến đi theo giờ trong ngày",
    x = "Giờ trong ngày",
    y = "Số lượng chuyến đi"
  ) +
  theme_minimal()

ggplot(weekday_trips_local, aes(x = pickup_weekday, y = total_trips)) +
  geom_bar(stat = "identity", fill = "orange") +
  labs(
    title = "Số lượng chuyến đi theo ngày trong tuần",
    x = "Ngày trong tuần",
    y = "Số lượng chuyến đi"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  theme_minimal()

# Lấy mẫu dữ liệu cho phân tích chi tiết
sampled_data <- taxi_data %>%
  sdf_sample(fraction = 0.01) %>%
  collect()

# Trực quan hóa phân phối fare_amount
ggplot(sampled_data, aes(x = fare_amount)) +
  geom_histogram(binwidth = 1, fill = "blue", color = "black") +
  labs(
    title = "Phân phối Fare Amount",
    x = "Fare Amount",
    y = "Số lượng chuyến đi"
  )

# Trực quan hóa mối quan hệ giữa thời gian và chi phí chuyến đi
ggplot(sampled_data, aes(x = log1p(trip_duration), y = log1p(total_fare))) +
  geom_point(alpha = 0.2) +
  geom_smooth(method = "lm", color = "red") +
  labs(
    title = "Mối quan hệ giữa log(chi phí) và log(thời gian chuyến đi)",
    x = "Log(Thời gian chuyến đi)",
    y = "Log(Chi phí chuyến đi)"
  )

# Xây dựng mô hình hồi quy tuyến tính
model_data <- taxi_data %>%
  select(total_fare, trip_duration, pickup_hour, pickup_weekday, trip_distance, tolls_amount, pickup_hour_group) %>%
  sdf_sample(fraction = 0.1) %>%
  collect()

# Xử lý lại các biến
model_data <- model_data %>%
  mutate(
    trip_duration = log1p(trip_duration),  # Giảm ảnh hưởng của ngoại lệ
    trip_distance = log1p(trip_distance),
    tolls_amount = log1p(tolls_amount + 1),  # Tránh giá trị 0
    pickup_weekday = as.factor(pickup_weekday),  # Chuyển thành categorical
    pickup_hour_group = as.factor(pickup_hour_group)
  )

# Xây dựng mô hình hồi quy tuyến tính
model <- lm(total_fare ~ trip_duration + trip_distance + pickup_hour + pickup_weekday + tolls_amount + pickup_hour_group, data = model_data)
summary(model)

# Kiểm tra phân phối phần dư 
plot(model, which = 1) # Residuals vs Fitted kiểm tra xem phần dư có phân bố ngẫu nhiên quanh đường trung bình không.
plot(model, which = 2) # Normal Q-Q kiểm tra xem phần dư (residuals) của mô hình hồi quy tuyến tính có phân phối chuẩn không.
