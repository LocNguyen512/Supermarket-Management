USE SupermarketDB


--TẶNG PHIẾU MUA HÀNG CHO KHÁCH HÀNG
CREATE PROC SP_TANGPHIEUMUAHANG_LOCK
AS
BEGIN
    SET NOCOUNT ON; 
    -- Khai báo biến
    DECLARE @SoDienThoai CHAR(10);
    DECLARE @NgaySinh DATE;
    DECLARE @MucKHTT NVARCHAR(10);
    DECLARE @NgayBatDau DATE = GETDATE();
    DECLARE @NgayKetThuc DATE = DATEADD(DAY, 30, @NgayBatDau); -- Phiếu có hạn 30 ngày
    DECLARE @MaPhieu NVARCHAR(50);

    -- Bắt đầu giao dịch với cấp độ Repeatable Read
    BEGIN TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    -- Cursor để duyệt qua khách hàng
    DECLARE KhachHangSNCursor CURSOR DYNAMIC LOCAL FORWARD_ONLY FOR
    SELECT SODIENTHOAI, NGAYSINH, MUCKHTT
    FROM KHACHHANG WITH (ROWLOCK); -- Khóa dòng khách hàng để đảm bảo dữ liệu không thay đổi trong quá trình xử lý

    OPEN KhachHangSNCursor;

    FETCH NEXT FROM KhachHangSNCursor INTO @SoDienThoai, @NgaySinh, @MucKHTT;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Kiểm tra ngày sinh có nằm trong khoảng từ ngày hiện tại đến cuối tháng tiếp theo
        IF CONVERT(VARCHAR(5), @NgaySinh, 110) BETWEEN 
           CONVERT(VARCHAR(5), @NgayBatDau, 110) AND 
           CONVERT(VARCHAR(5), DATEADD(MONTH, 1, @NgayBatDau), 110)
        BEGIN
            -- Tạo mã phiếu duy nhất
            WHILE 1 = 1
            BEGIN
                SET @MaPhieu = CAST(NEWID() AS NVARCHAR(50));

                -- Kiểm tra nếu mã đã tồn tại
                IF NOT EXISTS (SELECT 1 FROM PHIEUMUAHANG WHERE MAPHIEUMUAHANG = @MaPhieu)
                    BREAK; -- Thoát vòng lặp nếu mã là duy nhất
            END;

            -- Thêm phiếu mua hàng vào bảng PHIEUMUAHANG với XLOCK
            INSERT INTO PHIEUMUAHANG WITH (XLOCK) (MAPHIEUMUAHANG, SODIENTHOAI, NGAYHIEULUC, NGAYHETHAN, GIATRI, TRANGTHAI)
            VALUES (
                @MaPhieu,
                @SoDienThoai,
                @NgayBatDau,
                @NgayKetThuc,
                CASE @MucKHTT
                    WHEN N'Kim cương' THEN 1200000
                    WHEN N'Bạch kim' THEN 700000
                    WHEN N'Vàng' THEN 500000
                    WHEN N'Bạc' THEN 200000
                    WHEN N'Đồng' THEN 100000
                    ELSE 50000
                END,
                1 -- Trạng thái kích hoạt
            );
        END;

        -- Lấy khách hàng tiếp theo
        FETCH NEXT FROM KhachHangSNCursor INTO @SoDienThoai, @NgaySinh, @MucKHTT;
    END;

    -- Đóng và giải phóng cursor
    CLOSE KhachHangSNCursor;
    DEALLOCATE KhachHangSNCursor;

    -- Kết thúc giao dịch
    COMMIT TRANSACTION;
    SET NOCOUNT OFF;
END
GO



--Cập nhật hạng khách hàng thân thiết
CREATE PROC SP_CAPNHATKHTT_Lock
AS
BEGIN
    SET NOCOUNT ON;
    -- Biến lưu ngày hiện tại
    DECLARE @NgayHienTai DATE = GETDATE();
    DECLARE @SoDienThoai CHAR(10);
    DECLARE @NgayXet DATE;
    DECLARE @TongChiTieu INT;
	DECLARE @HangMoi NVARCHAR(10);

	BEGIN TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    -- Cursor để duyệt qua khách hàng
    DECLARE KhachHangCursor CURSOR LOCAL FORWARD_ONLY STATIC FOR
    SELECT SODIENTHOAI, NGAYXETKHTT
    FROM KHACHHANG WITH (ROWLOCK);

    OPEN KhachHangCursor;

    FETCH NEXT FROM KhachHangCursor INTO @SoDienThoai, @NgayXet;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Nếu NGAYXET là NULL, lấy NGAYDANGKI làm ngày bắt đầu
        IF @NgayXet IS NULL
        BEGIN
            SELECT @NgayXet = NGAYDANGKI FROM KHACHHANG WHERE SODIENTHOAI = @SoDienThoai;
        END

        -- Kiểm tra điều kiện thời gian (1 năm từ ngày xét cuối cùng)
        IF @NgayHienTai >= DATEADD(YEAR, 1, @NgayXet)
        BEGIN
            -- Tính tổng chi tiêu trong khoảng thời gian
            SELECT @TongChiTieu = SUM(THANHTIEN)
            FROM LSMUAHANG WITH (ROWLOCK)
            WHERE SODIENTHOAI = @SoDienThoai
              AND NGAYTHANHTOAN BETWEEN @NgayXet AND DATEADD(YEAR, 1, @NgayXet);

            -- Kiểm tra điều kiện nâng hạng
            IF @TongChiTieu >= 50000000 -- Điều kiện nâng hạng
            BEGIN
                SET @HangMoi = N'Kim cương';
            END
			ELSE IF @TongChiTieu < 50000000 and @TongChiTieu >= 30000000
			BEGIN
                SET @HangMoi = N'Bạch kim';
            END
			ELSE IF @TongChiTieu < 30000000 and @TongChiTieu >= 15000000
			BEGIN
                SET @HangMoi = N'Vàng';
            END
			ELSE IF @TongChiTieu < 15000000 and @TongChiTieu >= 5000000
			BEGIN
                SET @HangMoi = N'Bạc';
            END
			ELSE IF @TongChiTieu < 5000000 and @TongChiTieu > 0
			BEGIN
                SET @HangMoi = N'Đồng';
            END
			ELSE
			BEGIN
                SET @HangMoi = N'Thân thiết';
            END
        END
		UPDATE KHACHHANG WITH(XLOCK)
			SET MUCKHTT = @HangMoi, NgayXetKHTT = DATEADD(YEAR, 1, @NgayXet)
			WHERE SODIENTHOAI = @SoDienThoai

        -- Fetch next customer
        FETCH NEXT FROM KhachHangCursor INTO @SoDienThoai, @NgayXet;
    END

    CLOSE KhachHangCursor;
    DEALLOCATE KhachHangCursor;

	COMMIT TRANSACTION;
    SET NOCOUNT OFF;
END
GO


--SP XOA TAI KHOAN CO LOCK
CREATE PROC SP_SUATHONGTINLIENLAC 
	@SoDienThoaiCu CHAR(10), @TenKHCu NVARCHAR(255), @SoDienThoaiMoi CHAR(10), @TenKHMoi NVARCHAR(255), @NgaySinh DATE
AS
BEGIN
	SET NOCOUNT ON;
    BEGIN TRANSACTION;
	SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
	
	IF NOT EXISTS (SELECT 1 FROM KHACHHANG WITH (ROWLOCK) WHERE SODIENTHOAI = @SoDienThoaiCu AND NGAYSINH = @NgaySinh AND TENKH = @TenKHCu)
	BEGIN
		RAISERROR (N'Không tìm thấy tài khoản ứng với thông tin nhập vào!', 16,1);
		RETURN;
	END
	-- Kiểm tra số điện thoại mới đã tồn tại chưa (tránh trùng lặp)
    IF EXISTS (
        SELECT 1 
        FROM KHACHHANG   WITH (ROWLOCK)
        WHERE SODIENTHOAI = @SoDienThoaiMoi AND SODIENTHOAI != @SoDienThoaiCu
    )
    BEGIN
        RAISERROR (N'Số điện thoại mới đã được đăng ký cho tài khoản khác!', 16, 1);
        RETURN;
    END

	UPDATE KHACHHANG  WITH (XLOCK)
	SET SODIENTHOAI = @SoDienThoaiCu, TENKH  =@TenKHMoi
	WHERE SODIENTHOAI = @SoDienThoaiMoi
	
	PRINT N'Cập nhật thông tin thành công!';
		
	COMMIT TRANSACTION;
    SET NOCOUNT OFF;
END
GO


--SP xóa tài khoản khách hàng CO LOCK
CREATE PROC SP_XOATAIKHOAN_Lock
	@SoDienThoai CHAR(10), @TenKH NVARCHAR(255), @NgaySinh DATE
AS
BEGIN
	SET NOCOUNT ON;
    BEGIN TRANSACTION;
	SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
	
	IF NOT EXISTS (SELECT 1 FROM KHACHHANG  WITH (ROWLOCK) WHERE SODIENTHOAI = @SoDienThoai	AND NGAYSINH = @NgaySinh AND TENKH = @TenKH)
	BEGIN
		RAISERROR (N'Không tìm thấy tài khoản ứng với thông tin nhập vào!', 16,1);
		RETURN;
	END

	-- Kiểm tra các mối quan hệ liên quan (nếu có)
    IF EXISTS (
        SELECT 1 
        FROM LSMUAHANG  WITH (ROWLOCK)
        WHERE SODIENTHOAI = @SoDienThoai
    )
    BEGIN
        RAISERROR (N'Không thể xóa tài khoản vì đã có lịch sử mua hàng!', 16, 1);
        RETURN;
    END

	DELETE FROM KHACHHANG  WITH (XLOCK)
	WHERE SODIENTHOAI = @SoDienThoai

	PRINT N'Xóa tài khoản thành công!';

	COMMIT TRANSACTION;
    SET NOCOUNT OFF;
END
GO

