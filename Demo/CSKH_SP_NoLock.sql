USE SupermarketDB


--TẶNG PHIẾU MUA HÀNG CHO KHÁCH HÀNG
CREATE PROC SP_TANGPHIEUMUAHANG
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

    -- Cursor để duyệt qua khách hàng
    DECLARE KhachHangSNCursor CURSOR FOR
    SELECT SODIENTHOAI, NGAYSINH, MUCKHTT
    FROM KHACHHANG;

    OPEN KhachHangSNCursor;

    FETCH NEXT FROM KhachHangSNCursor INTO @SoDienThoai, @NgaySinh, @MucKHTT;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Kiểm tra ngày sinh có nằm trong khoảng xét
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

            -- Thêm phiếu mua hàng cho khách hàng
            INSERT INTO PHIEUMUAHANG (MAPHIEUMUAHANG, SODIENTHOAI, NGAYHIEULUC, NGAYHETHAN, GIATRI, TRANGTHAI)
            VALUES (
                @MaPhieu,
                @SoDienThoai,                   -- Số điện thoại khách hàng
                @NgayBatDau,                   -- Ngày hiệu lực
                @NgayKetThuc,                  -- Ngày hết hạn
                CASE @MucKHTT                   -- Giá trị phiếu dựa vào mức KHTT
                    WHEN N'Kim cương' THEN 1200000
                    WHEN N'Bạch kim' THEN 700000
                    WHEN N'Vàng' THEN 500000
                    WHEN N'Bạc' THEN 200000
                    WHEN N'Đồng' THEN 100000
                    ELSE 50000
                END,
                1                               -- Trạng thái kích hoạt
            );
        END;

        -- Lấy khách hàng tiếp theo
        FETCH NEXT FROM KhachHangSNCursor INTO @SoDienThoai, @NgaySinh, @MucKHTT;
    END;

    -- Đóng và giải phóng cursor
    CLOSE KhachHangSNCursor;
    DEALLOCATE KhachHangSNCursor;

    SET NOCOUNT OFF;
END;
GO



--Cập nhật hạng khách hàng thân thiết
CREATE PROC SP_CAPNHATKHTT
AS
BEGIN
    SET NOCOUNT ON;
	 

    -- Biến lưu ngày hiện tại
    DECLARE @NgayHienTai DATE = GETDATE();
    DECLARE @SoDienThoai CHAR(10);
    DECLARE @NgayXet DATE;
    DECLARE @TongChiTieu INT;
	DECLARE @HangMoi NVARCHAR(10);

    -- Cursor để duyệt qua khách hàng
    DECLARE KhachHangCursor CURSOR FOR
    SELECT SODIENTHOAI, NGAYXETKHTT
    FROM KHACHHANG;

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
            FROM LSMUAHANG
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
		UPDATE KHACHHANG
			SET MUCKHTT = @HangMoi, NgayXetKHTT = DATEADD(YEAR, 1, @NgayXet)
			WHERE SODIENTHOAI = @SoDienThoai

        -- Fetch next customer
        FETCH NEXT FROM KhachHangCursor INTO @SoDienThoai, @NgayXet;
    END

    CLOSE KhachHangCursor;
    DEALLOCATE KhachHangCursor;

	 
    SET NOCOUNT OFF;
END;
GO

--SP Tạo tài khoản khách hàng tt
CREATE PROC SP_TAOTAIKHOAN
	@SoDienThoai CHAR(10), @TenKH NVARCHAR(255), @NgaySinh DATE
AS 
BEGIN
	SET NOCOUNT ON;
     
	--KIEM TRA SDT
	IF EXISTS (SELECT 1 FROM KHACHHANG WHERE SODIENTHOAI = @SoDienThoai)
	BEGIN
		RAISERROR (N'Số điện thoại đã được đăng kí cho tài khoản khác',16,1);
		RETURN;
	END
	-- Kiểm tra tham số đầu vào
    IF @SoDienThoai IS NULL OR @TenKH IS NULL OR @NgaySinh IS NULL
    BEGIN
        RAISERROR (N'Thông tin không đầy đủ, vui lòng kiểm tra lại', 16, 1);
        RETURN; -- Thoát khỏi procedure
    END

	--THEM VAO BANG KHACHHANG TAI KHOAN MOI
	INSERT INTO KHACHHANG (SODIENTHOAI, TENKH, NGAYSINH,NGAYDANGKI,MUCKHTT)
	VALUES (@SoDienThoai, @TenKH, @NgaySinh, GETDATE() , N'Thân Thiết')

	PRINT N'Thêm tài khoản thành công!';

	 
    SET NOCOUNT OFF;
END
GO



--SP Sửa thông tin liên lạc cho khách hàng có nhu cầu thay đổi
CREATE PROC SP_SUATHONGTINLIENLAC 
	@SoDienThoaiCu CHAR(10), @TenKHCu NVARCHAR(255), @SoDienThoaiMoi CHAR(10), @TenKHMoi NVARCHAR(255), @NgaySinh DATE
AS
BEGIN
	SET NOCOUNT ON;
     
	
	IF NOT EXISTS (SELECT 1 FROM KHACHHANG WHERE SODIENTHOAI = @SoDienThoaiCu	AND NGAYSINH = @NgaySinh AND TENKH = @TenKHCu)
	BEGIN
		RAISERROR (N'Không tìm thấy tài khoản ứng với thông tin nhập vào!', 16,1);
		RETURN;
	END
	-- Kiểm tra số điện thoại mới đã tồn tại chưa (tránh trùng lặp)
    IF EXISTS (
        SELECT 1 
        FROM KHACHHANG 
        WHERE SODIENTHOAI = @SoDienThoaiMoi AND SODIENTHOAI != @SoDienThoaiCu
    )
    BEGIN
        RAISERROR (N'Số điện thoại mới đã được đăng ký cho tài khoản khác!', 16, 1);
        RETURN;
    END

	UPDATE KHACHHANG
	SET SODIENTHOAI = @SoDienThoaiCu, TENKH  =@TenKHMoi
	WHERE SODIENTHOAI = @SoDienThoaiMoi
	
	PRINT N'Cập nhật thông tin thành công!';
		
	 
    SET NOCOUNT OFF;
END
GO


--SP xóa tài khoản khách hàng 
CREATE PROC SP_XOATAIKHOAN
	@SoDienThoai CHAR(10), @TenKH NVARCHAR(255), @NgaySinh DATE
AS
BEGIN
	SET NOCOUNT ON;
     
	
	IF NOT EXISTS (SELECT 1 FROM KHACHHANG WHERE SODIENTHOAI = @SoDienThoai	AND NGAYSINH = @NgaySinh AND TENKH = @TenKH)
	BEGIN
		RAISERROR (N'Không tìm thấy tài khoản ứng với thông tin nhập vào!', 16,1);
		RETURN;
	END

	-- Kiểm tra các mối quan hệ liên quan (nếu có)
    IF EXISTS (
        SELECT 1 
        FROM LSMUAHANG 
        WHERE SODIENTHOAI = @SoDienThoai
    )
    BEGIN
        RAISERROR (N'Không thể xóa tài khoản vì đã có lịch sử mua hàng!', 16, 1);
        RETURN;
    END

	DELETE FROM KHACHHANG
	WHERE SODIENTHOAI = @SoDienThoai

	PRINT N'Xóa tài khoản thành công!';

	 
    SET NOCOUNT OFF;
END
GO

--Xóa pmh nếu đã sử dụng xong
CREATE PROC SP_XOAPHIEUMUAHANG
	@MaPhieu VARCHAR(50)
AS
BEGIN
	SET NOCOUNT ON;
     
	
	IF NOT EXISTS (SELECT 1 FROM PHIEUMUAHANG WHERE MAPHIEUMUAHANG  =@MaPhieu)
	BEGIN
		RAISERROR (N'Mã phiếu mua hàng không tồn tại',16,1);
		RETURN;
	END
	-- Kiểm tra xem phiếu đã được sử dụng hay chưa
    IF EXISTS (SELECT 1 FROM PHIEUMUAHANG WHERE MAPHIEUMUAHANG = @MaPhieu AND TRANGTHAI = 1)
    BEGIN
        RAISERROR (N'Không thể xóa mã phiếu mua hàng chưa sử dụng', 16, 1);
        RETURN;
    END

	DELETE FROM PHIEUMUAHANG 
	WHERE MAPHIEUMUAHANG = @MaPhieu

	PRINT N'Xóa mã phiếu mua hàng thành công!';

	 
    SET NOCOUNT OFF;
END;
GO

CREATE PROC SP_KIEMTRAPHIEUMUAHANG
    @SoDienThoai CHAR(10)
AS
BEGIN
	SET NOCOUNT ON;
     
    -- Kiểm tra số điện thoại khách hàng có tồn tại hay không
    IF NOT EXISTS (SELECT 1 FROM KHACHHANG WHERE SODIENTHOAI = @SoDienThoai)
    BEGIN
        RAISERROR (N'Số điện thoại khách hàng không tồn tại!', 16, 1);
        RETURN;
    END

    -- Kiểm tra tình trạng phiếu mua hàng của khách hàng
    IF EXISTS (SELECT 1 FROM PHIEUMUAHANG WHERE SODIENTHOAI = @SoDienThoai)
    BEGIN
        SELECT * 
        FROM PHIEUMUAHANG
        WHERE SODIENTHOAI = @SoDienThoai;
    END
    ELSE
    BEGIN
        PRINT N'Không tìm thấy phiếu mua hàng nào liên quan đến số điện thoại này.';
    END

	 
    SET NOCOUNT OFF;
END
GO

