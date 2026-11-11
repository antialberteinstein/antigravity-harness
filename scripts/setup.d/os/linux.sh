# setup.d/os/linux.sh — dự phòng cho bản Linux chưa có hồ sơ riêng.
# Dùng nguyên hành vi mặc định trong lib.sh: không tự cài gì, chỉ gợi ý.
# Muốn hỗ trợ một bản cụ thể (vd. Ubuntu, Arch): tạo os/<ID>.sh, với <ID> lấy từ /etc/os-release
# (Ubuntu khai báo ID_LIKE=debian nên một file os/debian.sh dùng được cho cả hai).
OS_LABEL="Linux (chung)"
