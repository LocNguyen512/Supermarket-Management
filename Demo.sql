-- USE master
USE SupermarketDB
GO

/*BỘ PHẬN CHĂM SÓC KHÁCH HÀNG*/
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
    DECLARE @NgayKetThuc DATE = DATEADD(DAY, 30, @NgayBatDau); 
    DECLARE @MaPhieu NVARCHAR(50);

    -- Cursor để duyệt qua khách hàng
    DECLARE KhachHangSNCursor CURSOR FOR
    SELECT SODIENTHOAI, NGAYSINH, MUCKHTT
    FROM KHACHHANG;

    OPEN KhachHangSNCursor;

    FETCH NEXT FROM KhachHangSNCursor INTO @SoDienThoai, @NgaySinh, @MucKHTT;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        --Kiểm tra số điện thoại khách hàng này có tồn tại không
		IF NOT EXISTS (SELECT 1 FROM KHACHHANG WHERE SODIENTHOAI = @SoDienThoai)
		BEGIN
			RAISERROR (N'Không tìm thấy số điện thoại này trong dữ liệu khách hàng',16,1);
			RETURN;
		END


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


			--(chổ này) đọc lấy mã khtt của khách hàng
			IF EXISTS (SELECT MUCKHTT FROM KHACHHANG WHERE SODIENTHOAI = @SoDienThoai)
			BEGIN
				SET @MucKHTT = (SELECT MUCKHTT FROM KHACHHANG WHERE SODIENTHOAI = @SoDienThoai)
			END
			ELSE 
			BEGIN
				RAISERROR (N'Không tìm thấy dữ liệu khách hàng này',16,1);
				RETURN;
			END


            -- Thêm phiếu mua hàng cho khách hàng
            INSERT INTO PHIEUMUAHANG (MAPHIEUMUAHANG, SODIENTHOAI, NGAYHIEULUC, NGAYHETHAN, GIATRI, TRANGTHAI)
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
                END,1);
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
	-- Kiểm tra tham số đầu vào
    IF @SoDienThoai IS NULL OR @TenKH IS NULL OR @NgaySinh IS NULL
    BEGIN
        RAISERROR (N'Thông tin không đầy đủ, vui lòng kiểm tra lại', 16, 1);
        RETURN; -- Thoát khỏi procedure
    END
     
	--KIEM TRA SDT
	IF EXISTS (SELECT 1 FROM KHACHHANG WHERE SODIENTHOAI = @SoDienThoai)
	BEGIN
		RAISERROR (N'Số điện thoại đã được đăng kí cho tài khoản khác',16,1);
		RETURN;
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

-------------------------------------------------------------------------------------------------------
/*BỘ PHẬN QUẢN LÝ NGÀNH HÀNG*/
-- 1.THÊM SẢN PHẨM
CREATE OR ALTER PROCEDURE SP_THEM_SAN_PHAM
    @MASP INT,
    @TENSP NVARCHAR(255),
    @MOTA NVARCHAR(200),
    @TENNSX NVARCHAR(100),
    @GIA DECIMAL(15,2),
    @TENDANHMUC NVARCHAR(100),
    @SLSPTD INT,
    @SLTK INT
AS
BEGIN
	BEGIN TRANSACTION;
    -- Kiểm tra mã sản phẩm phải chưa tồn tại
    IF EXISTS (
        SELECT 1
        FROM SANPHAM
        WHERE MASP = @MASP
    )
    BEGIN
        RAISERROR (N'Mã sản phẩm đã tồn tại.', 16, 1);
        RETURN;
    END

    -- Xác định mã nhà sản xuất dựa trên tên nhà sản xuất
    DECLARE @MANSX INT;
    SELECT @MANSX = MANSX
    FROM NHASX
    WHERE TENNSX = @TENNSX;

    IF @MANSX IS NULL
    BEGIN
        RAISERROR (N'Nhà sản xuất không tồn tại.', 16, 1);
        RETURN;
    END

    -- Xác định mã danh mục dựa trên tên danh mục
    DECLARE @MADANHMUC INT;
    SELECT @MADANHMUC = MADANHMUC
    FROM DANHMUC
    WHERE TENDANHMUC = @TENDANHMUC;

    IF @MADANHMUC IS NULL
    BEGIN
        RAISERROR (N'Danh mục không tồn tại.', 16, 1);
        RETURN;
    END

    -- Thêm sản phẩm vào bảng SANPHAM
    INSERT INTO SANPHAM (MASP, TENSP, MOTA, MANSX, GIA, MADANHMUC, SLSPTD, SOLUONGTON)
    VALUES (@MASP, @TENSP, @MOTA, @MANSX, @GIA, @MADANHMUC, @SLSPTD, @SLTK);
	COMMIT TRANSACTION;
    PRINT N'Thêm sản phẩm thành công';
END
GO

-- EXEC SP_THEM_SAN_PHAM 1, N'Áo thun', N'100% cotton', 'SamSung', 100000, N'Thời trang', 500, 300

-- 2.Thêm khuyến mãi
CREATE OR ALTER PROCEDURE SP_THEM_KHUYEN_MAI 
    @MAKHUYENMAI NVARCHAR(50),
    @MASP1 INT,
    @MASP2 INT = NULL,
    @MALOAIKHUYENMAI INT,
    @TYLEGIAM FLOAT,
    @NGAYBATDAU DATE,
    @NGAYKETTHUC DATE,
    @SOLUONGTOIDA INT,
    @MUCKHTT NVARCHAR(10) = NULL
AS
BEGIN
	BEGIN TRANSACTION;
    -- Kiểm tra mã khuyến mãi có tồn tại không
    IF EXISTS (SELECT 1 FROM KHUYENMAI WHERE MAKHUYENMAI = @MAKHUYENMAI)
    BEGIN
        THROW 50001, N'MÃ KHUYẾN MÃI ĐÃ TỒN TẠI', 1;
    END

    -- Kiểm tra sản phẩm có tồn tại không
    IF NOT EXISTS (SELECT 1 FROM SANPHAM WHERE MASP = @MASP1)
    BEGIN
        THROW 50002, N'MÃ SẢN PHẨM KHÔNG TỒN TẠI', 1;
    END

    IF @MASP2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM SANPHAM WHERE MASP = @MASP2)
    BEGIN
        THROW 50003, N'MÃ SẢN PHẨM THỨ HAI KHÔNG TỒN TẠI', 1;
    END

    -- Kiểm tra tồn kho
    DECLARE @SLTON1 INT;
    SELECT @SLTON1 = SOLUONGTON FROM SANPHAM WHERE MASP = @MASP1;

    IF @SOLUONGTOIDA > @SLTON1
    BEGIN
        THROW 50004, N'KHO KHÔNG ĐỦ SỐ LƯỢNG SẢN PHẨM', 1;
    END

    IF @MASP2 IS NOT NULL
    BEGIN
		IF @MALOAIKHUYENMAI IN ('1', '3') 
		BEGIN
			THROW 50005, N'LOẠI KHUYẾN MÃI KHÔNG PHÙ HỢP', 1;
		END

        DECLARE @SLTON2 INT;
        SELECT @SLTON2 = SOLUONGTON FROM SANPHAM WHERE MASP = @MASP2;

        IF @SOLUONGTOIDA > @SLTON2
        BEGIN
            THROW 50004, N'KHO KHÔNG ĐỦ SỐ LƯỢNG SẢN PHẨM THỨ HAI', 1;
        END
    END

    -- Kiểm tra loại khuyến mãi
    IF @MALOAIKHUYENMAI NOT IN ('1', '2', '3') 
    BEGIN
        THROW 50005, N'LOẠI KHUYẾN MÃI KHÔNG PHÙ HỢP', 1;
    END

    -- Thêm khuyến mãi vào bảng KHUYENMAI
    INSERT INTO KHUYENMAI (MAKHUYENMAI, MALOAIKHUYENMAI, TYLEGIAM, NGAYBATDAU, NGAYKETTHUC, SOLUONGTOIDA)
    VALUES (@MAKHUYENMAI, @MALOAIKHUYENMAI, @TYLEGIAM, @NGAYBATDAU, @NGAYKETTHUC, @SOLUONGTOIDA);

    -- Xử lý từng loại khuyến mãi
    IF @MALOAIKHUYENMAI = '3' -- MEMBER-SALE
    BEGIN
        IF @MUCKHTT NOT IN (N'THÂN THIẾT', N'ĐỒNG', N'BẠC', N'VÀNG', N'KIM CƯƠNG')
        BEGIN
            THROW 50006, N'HẠNG KHÁCH HÀNG KHÔNG PHÙ HỢP', 1;
        END

        INSERT INTO KHUYENMAI_KHACHHANG (MAKHUYENMAI, MUCKHTT, TYLEGIAM)
        VALUES (@MAKHUYENMAI, @MUCKHTT, @TYLEGIAM);

        INSERT INTO SANPHAM_KHUYENMAI (MASP, KHUYENMAIID)
        VALUES (@MASP1, @MAKHUYENMAI);
    END
    ELSE IF @MALOAIKHUYENMAI = '2' -- COMBO-SALE
    BEGIN
        INSERT INTO SANPHAM_KHUYENMAI (MASP, KHUYENMAIID)
        VALUES (@MASP1, @MAKHUYENMAI);

        INSERT INTO SANPHAM_KHUYENMAI (MASP, KHUYENMAIID)
        VALUES (@MASP2, @MAKHUYENMAI);
    END
    ELSE IF @MALOAIKHUYENMAI = '1' -- FLASH-SALE
    BEGIN
        INSERT INTO SANPHAM_KHUYENMAI (MASP, KHUYENMAIID)
        VALUES (@MASP1, @MAKHUYENMAI);
    END
	COMMIT TRANSACTION;
    PRINT N'THÊM KHUYẾN MÃI THÀNH CÔNG.';
END;
GO

/*
SELECT * FROM SANPHAM
SELECT * FROM KHUYENMAI
SELECT * FROM SANPHAM_KHUYENMAI
SELECT * FROM KHUYENMAI_KHACHHANG
EXEC SP_THEM_KHUYEN_MAI '14', 1, NULL, '1', 50,'2024-12-28','2024-12-30', 200, NULL
EXEC SP_THEM_KHUYEN_MAI '16', 1, 2, '2', 50,'2024-12-28','2024-12-30', 10, NULL
EXEC SP_THEM_KHUYEN_MAI '17', 1, NULL, '3', 50,'2024-12-28','2024-12-30', 20, N'THÂN THIẾT'
*/

-- 3.KIẾM TRA ÁP DỤNG KHUYẾN MÃI
CREATE OR ALTER PROCEDURE SP_KIEMTRA_APDUNG_KHUYENMAI
    @MASP INT,
    @NGAYHIENTAI DATE,
    @MUCKHTT NVARCHAR(50)
AS
BEGIN
	BEGIN TRANSACTION;
    -- Kiểm tra sản phẩm có hợp lệ không
    IF NOT EXISTS (SELECT 1 FROM SANPHAM WHERE MASP = @MASP)
    BEGIN
        RAISERROR (N'SẢN PHẨM KHÔNG HỢP LỆ', 16, 1);
        RETURN;
    END

    -- Kiểm tra mức khách hàng thân thiết có hợp lệ không
    IF @MUCKHTT NOT IN (N'THÂN THIẾT', N'ĐỒNG', N'BẠC', N'VÀNG', N'KIM CƯƠNG')
    BEGIN
        RAISERROR (N'MỨC KHÁCH HÀNG THÂN THIẾT KHÔNG HỢP LỆ', 16, 1);
        RETURN;
    END

    -- Bảng kết quả trả về
    CREATE TABLE #KHUYENMAI_THONGTIN (
        TENCHUONGTRINH NVARCHAR(255),
        NGAYBATDAU DATE,
        NGAYKETTHUC DATE,
        LOAIKM NVARCHAR(50),
        TYLEGIAM DECIMAL(5, 2)
    );

    -- Lấy danh sách mã khuyến mãi áp dụng cho sản phẩm
    DECLARE @KHUYENMAI_CURSOR CURSOR;
    DECLARE @MAKHUYENMAI NVARCHAR(50), @LOAIKM NVARCHAR(50), @TYLEGIAM DECIMAL(5, 2);

    SET @KHUYENMAI_CURSOR = CURSOR FOR
    SELECT DISTINCT KM.MAKHUYENMAI, KM.MALOAIKHUYENMAI, KM.TYLEGIAM
    FROM KHUYENMAI KM
    INNER JOIN SANPHAM_KHUYENMAI SPKM ON KM.MAKHUYENMAI = SPKM.KHUYENMAIID
    WHERE SPKM.MASP = @MASP
      AND @NGAYHIENTAI BETWEEN KM.NGAYBATDAU AND KM.NGAYKETTHUC
      AND KM.SOLUONGTOIDA > 0;

    OPEN @KHUYENMAI_CURSOR;

    FETCH NEXT FROM @KHUYENMAI_CURSOR INTO @MAKHUYENMAI, @LOAIKM, @TYLEGIAM;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Nếu là membersale
        IF @LOAIKM = '3' -- Membersale
        BEGIN
            DECLARE @TYLEGIAM_MEMBER DECIMAL(5, 2);
            SELECT @TYLEGIAM_MEMBER = TYLEGIAM
            FROM KHUYENMAI_KHACHHANG
            WHERE MAKHUYENMAI = @MAKHUYENMAI AND MUCKHTT = @MUCKHTT;

            IF @TYLEGIAM_MEMBER IS NOT NULL
            BEGIN
                INSERT INTO #KHUYENMAI_THONGTIN (TENCHUONGTRINH, NGAYBATDAU, NGAYKETTHUC, LOAIKM, TYLEGIAM)
                SELECT KM.MAKHUYENMAI, KM.NGAYBATDAU, KM.NGAYKETTHUC, 'membersale', @TYLEGIAM_MEMBER
                FROM KHUYENMAI KM
                WHERE KM.MAKHUYENMAI = @MAKHUYENMAI;
            END
        END
        ELSE IF @LOAIKM IN ('1', '2') -- Combo-sale or Flash-sale
        BEGIN
            INSERT INTO #KHUYENMAI_THONGTIN (TENCHUONGTRINH, NGAYBATDAU, NGAYKETTHUC, LOAIKM, TYLEGIAM)
            SELECT KM.MAKHUYENMAI, KM.NGAYBATDAU, KM.NGAYKETTHUC,
                   CASE WHEN @LOAIKM = '1' THEN 'flash-sale' ELSE 'combo-sale' END, @TYLEGIAM
            FROM KHUYENMAI KM
            WHERE KM.MAKHUYENMAI = @MAKHUYENMAI;
        END

        FETCH NEXT FROM @KHUYENMAI_CURSOR INTO @MAKHUYENMAI, @LOAIKM, @TYLEGIAM;
    END

    CLOSE @KHUYENMAI_CURSOR;
    DEALLOCATE @KHUYENMAI_CURSOR;

    -- Trả về kết quả
    SELECT * FROM #KHUYENMAI_THONGTIN;

    DROP TABLE #KHUYENMAI_THONGTIN;
	COMMIT TRANSACTION;
END
GO

--EXEC SP_KIEMTRA_APDUNG_KHUYENMAI 1, '2024-12-28', N'THÂN THIẾT'

-- 4. Xóa sản phẩm
CREATE PROCEDURE SP_XOA_SAN_PHAM
    @MASP INT
AS
BEGIN
	BEGIN TRANSACTION;
    -- Kiểm tra mã sản phẩm phải tồn tại
    IF NOT EXISTS (
        SELECT 1
        FROM SANPHAM
        WHERE MASP = @MASP
    )
    BEGIN
        RAISERROR (N'Mã sản phẩm không tồn tại.', 16, 1);
        RETURN;
    END

    -- Xóa các khuyến mãi liên quan sản phẩm
    DELETE FROM SANPHAM_KHUYENMAI
    WHERE MASP = @MASP;

    -- Xóa sản phẩm
    DELETE FROM SANPHAM
    WHERE MASP = @MASP;
	COMMIT TRANSACTION;
    PRINT N'Xóa sản phẩm và các khuyến mãi liên quan thành công';
END
GO

-- EXEC SP_XOA_SAN_PHAM 2

-------------------------------------------------------------------------------------------------------
--/*BỘ PHẬN XỬ LÝ ĐƠN HÀNG*/
﻿﻿﻿
GO
CREATE PROCEDURE SP_XU_LI_DON @MADONHANG NVARCHAR(50)
AS
BEGIN 
	DECLARE @SDT CHAR(10)
	IF EXISTS (SELECT 1 FROM DONHANG AS DH WHERE DH.DONHANGID=@MADONHANG)
		BEGIN

			DECLARE @TONG DECIMAL(18,2)
			DECLARE @GIATRI INT
			DECLARE @NGAYHIEULUC DATE
			DECLARE @NGAYHETHAN DATE
			DECLARE @TRANGTHAI BIT

			SELECT @TONG=SUM(CTDH.GIASAPDUNG)
			FROM CHITIETDONHANG AS CTDH
			WHERE CTDH.DONHANGID=@MADONHANG


			SELECT @SDT=DH.SO_DIEN_THOAI
			FROM DONHANG AS DH
			WHERE DH.DONHANGID=@MADONHANG

			IF EXISTS(SELECT 1 FROM PHIEUMUAHANG AS PMH WHERE PMH.SODIENTHOAI=@SDT)
				BEGIN
					SELECT @GIATRI=PMH.GIATRI, @NGAYHETHAN=PMH.NGAYHETHAN, @NGAYHIEULUC=PMH.NGAYHIEULUC, @TRANGTHAI=PMH.TRANGTHAI
					FROM PHIEUMUAHANG AS PMH WHERE PMH.SODIENTHOAI=@SDT

					IF(@NGAYHIEULUC<=GETDATE() AND @NGAYHETHAN>=GETDATE() AND @TRANGTHAI=1)
						BEGIN
							SET @TONG=@TONG-@GIATRI
						END
				END

			UPDATE DONHANG SET TONGGIATRI=@TONG WHERE DONHANGID=@MADONHANG
			UPDATE PHIEUMUAHANG SET TRANGTHAI=0 WHERE SODIENTHOAI=@SDT
			DELETE FROM PHIEUMUAHANG WHERE SODIENTHOAI=@SDT
			SELECT*FROM DONHANG AS DH WHERE DH.DONHANGID=@MADONHANG
			
		END
	ELSE
		BEGIN
			RAISERROR(N'Không tìm thấy mã đơn hàng',16,1)
		END
END
GO

EXEC SP_XU_LI_DON '1'



GO
CREATE PROC SP_TAO_CHI_TIET_DON_HANG @DONHANGID NVARCHAR(50), @MASP INT, @SOLUONG INT
AS
BEGIN
	
	IF EXISTS(SELECT 1 FROM SANPHAM AS SP WHERE SP.MASP=@MASP)
		BEGIN
			IF(@SOLUONG>0)
				BEGIN
					DECLARE @SLT INT
					SELECT @SLT=SP.SOLUONGTON
					FROM SANPHAM AS SP
					WHERE SP.MASP=@MASP

					IF(@SLT>@SOLUONG)
						BEGIN
							INSERT INTO CHITIETDONHANG (DONHANGID, MASP, SOLUONG) VALUES (@DONHANGID, @MASP, @SOLUONG)
							UPDATE SANPHAM
							SET SOLUONGTON=@SLT-@SOLUONG
							WHERE MASP=@MASP
						END
					ELSE
						BEGIN
							RAISERROR(N'Không đủ số lượng',16,1)
						END
					
				END
			ELSE
				BEGIN
					RAISERROR(N'Số lượng sản phẩm phải lớn hơn 0',16,1)
				END
		END
	ELSE
		BEGIN
			RAISERROR(N'Không tìm thấy mã sản phẩm phù hợp',16,1);
		END

END
GO

--EXEC SP_TAO_CHI_TIET_DON_HANG '5', 1, 2
--EXEC SP_TAO_CHI_TIET_DON_HANG '5', 3, 1

--SELECT*FROM CHITIETDONHANG WHERE DONHANGID='5'



GO
CREATE PROC SP_TIM_KHUYEN_MAI_TOT_NHAT @DONHANGID NVARCHAR(50)
AS
BEGIN
	DECLARE @SDT CHAR(10)

	SELECT @SDT=DH.SO_DIEN_THOAI
	FROM DONHANG AS DH
	WHERE DH.DONHANGID=@DONHANGID

	CREATE TABLE #TEMPCT
	(
		MASP INT,
		SOLUONG INT,
		GIA DECIMAL(15,2),
		KHUYENMAIID NVARCHAR(50),
		TYLEGIAM FLOAT,
		GIASAPDUNG DECIMAL(15,2)

	)

	INSERT INTO #TEMPCT(MASP, SOLUONG) 
	SELECT CTDH.MASP, CTDH.SOLUONG
	FROM CHITIETDONHANG AS CTDH
	WHERE CTDH.DONHANGID=@DONHANGID

	UPDATE T
	SET T.GIA = SP.GIA
	FROM #TEMPCT AS T
	JOIN SANPHAM AS SP ON SP.MASP = T.MASP;

	--Tìm flash-sale tốt nhất cho các sản phẩm
	SELECT T.MASP, KM.MAKHUYENMAI, MAX(KM.TYLEGIAM) AS TYLEGIAM
	INTO #TEMP2
	FROM #TEMPCT AS T
	JOIN SANPHAM_KHUYENMAI AS SPKM ON SPKM.MASP=T.MASP
	JOIN KHUYENMAI AS KM ON KM.MAKHUYENMAI=SPKM.KHUYENMAIID
	WHERE KM.MALOAIKHUYENMAI=1
	GROUP BY T.MASP, KM.MAKHUYENMAI

	UPDATE T
	SET T.KHUYENMAIID = T2.MAKHUYENMAI, T.TYLEGIAM = T2.TYLEGIAM
	FROM #TEMPCT AS T
	JOIN #TEMP2 AS T2 ON T.MASP = T2.MASP;

	--Nếu toàn bộ sản phẩm đều có flash-sale
		UPDATE #TEMPCT
			SET GIASAPDUNG = GIA * (1 - (TYLEGIAM / 100)) * 
                 CASE 
                     WHEN SOLUONG > 3 THEN 3
                     ELSE SOLUONG
                 END;
		IF EXISTS (SELECT 1 FROM #TEMPCT WHERE KHUYENMAIID is NULL)
			BEGIN
				SELECT T.MASP, KM.MAKHUYENMAI, MAX(KM.TYLEGIAM) AS TYLEGIAM
				INTO #TEMP3
				FROM #TEMPCT AS T
				JOIN SANPHAM_KHUYENMAI AS SPKM ON SPKM.MASP=T.MASP
				JOIN KHUYENMAI AS KM ON KM.MAKHUYENMAI=SPKM.KHUYENMAIID
				WHERE KM.MALOAIKHUYENMAI=2 AND T.KHUYENMAIID IS NULL AND T.SOLUONG>=2
				GROUP BY T.MASP, KM.MAKHUYENMAI

				UPDATE T
				SET T.KHUYENMAIID = T3.MAKHUYENMAI, T.TYLEGIAM = T3.TYLEGIAM
				FROM #TEMPCT AS T
				JOIN #TEMP3 AS T3 ON T.MASP = T3.MASP


				UPDATE T
				SET GIASAPDUNG = T.GIA * (1 - (T.TYLEGIAM / 100)) * 2
				FROM #TEMPCT AS T
				JOIN #TEMP3 AS T3 ON T.MASP=T3.MASP
			END
		--Tìm tiếp combo-sale
		IF EXISTS (SELECT 1 FROM #TEMPCT WHERE KHUYENMAIID is NULL)
			BEGIN
				CREATE TABLE #TEMP4 
				(	
					MASP1 INT,
					MASP2 INT,
					MAKHUYENMAI NVARCHAR(50),
					TYLEGIAM FLOAT
				)
				IF EXISTS (
					SELECT 1
					FROM SANPHAM_KHUYENMAI AS SP1
					JOIN SANPHAM_KHUYENMAI AS SP2 
						ON SP1.KHUYENMAIID = SP2.KHUYENMAIID -- Cùng mã khuyến mãi
						AND SP1.MASP != SP2.MASP             -- Đảm bảo không trùng lặp cặp sản phẩm
					JOIN KHUYENMAI AS KM 
						ON SP1.KHUYENMAIID = KM.MAKHUYENMAI
					WHERE KM.MALOAIKHUYENMAI = 2 -- Combo-sale
						AND KM.NGAYBATDAU <= GETDATE() 
						AND KM.NGAYKETTHUC >= GETDATE()
						AND SP1.SLAPDUNG > 0 AND SP2.SLAPDUNG > 0
				)
					BEGIN
						INSERT INTO #TEMP4 (MASP1, MASP2, MAKHUYENMAI, TYLEGIAM)
						SELECT 
							SP1.MASP AS MASP1,
							SP2.MASP AS MASP2,
							KM.MAKHUYENMAI,
							KM.TYLEGIAM
						FROM SANPHAM_KHUYENMAI AS SP1
						JOIN SANPHAM_KHUYENMAI AS SP2 ON SP1.KHUYENMAIID = SP2.KHUYENMAIID
							AND SP1.MASP != SP2.MASP
						JOIN KHUYENMAI AS KM ON SP1.KHUYENMAIID = KM.MAKHUYENMAI
						WHERE KM.MALOAIKHUYENMAI = 3
							AND KM.NGAYBATDAU <= GETDATE()
							AND KM.NGAYKETTHUC >= GETDATE()
							AND SP1.SLAPDUNG > 0 AND SP2.SLAPDUNG > 0
							AND KM.TYLEGIAM = ( -- Chọn mức giảm giá cao nhất
								SELECT MAX(KM2.TYLEGIAM)
								FROM KHUYENMAI AS KM2
								JOIN SANPHAM_KHUYENMAI AS SPKM 
									ON KM2.MAKHUYENMAI = SPKM.KHUYENMAIID
								WHERE SPKM.MASP IN (SP1.MASP, SP2.MASP)
								  AND KM2.MALOAIKHUYENMAI = 3
								  AND KM2.NGAYBATDAU <= GETDATE()
								  AND KM2.NGAYKETTHUC >= GETDATE()
							);
					END

					UPDATE T
					SET T.KHUYENMAIID = T4.MAKHUYENMAI, T.TYLEGIAM = T4.TYLEGIAM
					FROM #TEMPCT AS T
					JOIN #TEMP4 AS T4 ON T.MASP = T4.MASP1 OR T.MASP=T4.MASP2
				

					UPDATE #TEMPCT
					SET GIASAPDUNG = T.GIA * (1 - (T.TYLEGIAM / 100)) * 
						CASE
							WHEN T.SOLUONG > 3 THEN 3
							ELSE T.SOLUONG
						END
					FROM #TEMPCT AS T
					JOIN #TEMP4 AS T4 ON T.MASP=T4.MASP1 OR T.MASP=T4.MASP2

			END
		--Tìm member-sale
		IF EXISTS (SELECT 1 FROM #TEMPCT AS T WHERE T.KHUYENMAIID IS NULL)
			BEGIN
				DECLARE @MUCKH NVARCHAR(50)
							IF EXISTS (SELECT 1 FROM KHACHHANG AS KH WHERE KH.SODIENTHOAI=@SDT)
								BEGIN
									CREATE TABLE #TEMP5 (
									MASP INT,
									MAKHUYENMAI NVARCHAR(50),
									TYLEGIAM FLOAT
									)

									INSERT INTO #TEMP5(MASP, MAKHUYENMAI)
									SELECT T.MASP, SPKM.KHUYENMAIID
									FROM #TEMPCT AS T
									JOIN SANPHAM_KHUYENMAI AS SPKM ON SPKM.MASP=T.MASP
									JOIN KHUYENMAI AS KM ON SPKM.KHUYENMAIID=KM.MAKHUYENMAI
									WHERE T.KHUYENMAIID IS NULL AND KM.MALOAIKHUYENMAI=3

									SELECT @MUCKH=KH.MUCKHTT
									FROM KHACHHANG AS KH
									WHERE KH.SODIENTHOAI=@SDT

									DECLARE @TYLEGIAM FLOAT
									SELECT @TYLEGIAM=KMKH.TYLEGIAM
									FROM KHUYENMAI_KHACHHANG AS KMKH
									WHERE KMKH.MUCKHTT=@MUCKH

									UPDATE #TEMP5 SET TYLEGIAM=@TYLEGIAM

									UPDATE T
									SET T.KHUYENMAIID = T5.MAKHUYENMAI, T.TYLEGIAM = T5.TYLEGIAM
									FROM #TEMPCT AS T
									JOIN #TEMP5 AS T5 ON T.MASP = T5.MASP

									UPDATE #TEMPCT
									SET GIASAPDUNG = T.GIA * (1 - (T.TYLEGIAM / 100)) *
										CASE
											WHEN T.SOLUONG>3 THEN 3
											ELSE T.SOLUONG
										END
									FROM #TEMPCT AS T
									JOIN #TEMP5 AS T5 ON T.MASP=T5.MASP
								END
			END
		--Nếu sản phẩm không có loại sale nào phù hợp
		IF EXISTS (SELECT 1 FROM #TEMPCT WHERE KHUYENMAIID IS NULL)
			BEGIN
				UPDATE T
				SET T.GIASAPDUNG=SP.GIA, T.TYLEGIAM=0 
				FROM #TEMPCT AS T
				JOIN SANPHAM AS SP ON T.MASP=SP.MASP AND T.KHUYENMAIID IS NULL

				UPDATE #TEMPCT SET GIASAPDUNG = GIA * (1 - TYLEGIAM / 100) *SOLUONG WHERE KHUYENMAIID IS NULL 
				
			END
			SELECT *FROM #TEMPCT

			UPDATE CTDH
			SET CTDH.KHUYENMAIID=CTDH.KHUYENMAIID, CTDH.GIASAPDUNG=T.GIASAPDUNG
			FROM CHITIETDONHANG AS CTDH
			JOIN #TEMPCT AS T ON T.MASP=CTDH.MASP
		
END
GO

--EXEC SP_TIM_KHUYEN_MAI_TOT_NHAT '5'




-------------------------------------------------------------------------------------------------------
/*BỘ PHẬN QUẢN LÝ KHO HÀNG*/
-- KIỂM TRA TỒN KHO
CREATE PROCEDURE SP_KIEMTRA_TONKHO
AS
BEGIN

    -- Khai báo các biến để lưu dữ liệu từ con trỏ
    DECLARE @MASP NVARCHAR(50)
    DECLARE @TENSP NVARCHAR(255)
    DECLARE @SOLUONGTON INT

    -- Khai báo con trỏ
    DECLARE ProductCursor CURSOR FOR
    SELECT MASP, TENSP, SOLUONGTON
    FROM SANPHAM

    -- Mở con trỏ
    OPEN ProductCursor

    -- Lấy dữ liệu đầu tiên từ con trỏ
    FETCH NEXT FROM ProductCursor INTO @MASP, @TENSP, @SOLUONGTON

    -- Vòng lặp duyệt qua từng bản ghi
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- In hoặc xử lý dữ liệu (ở đây là in ra màn hình)
        PRINT 'Mã sản phẩm: ' + @MASP + ', Tên sản phẩm: ' + @TENSP + ', Số lượng tồn: ' + CAST(@SOLUONGTON AS NVARCHAR)

        -- Lấy bản ghi tiếp theo
        FETCH NEXT FROM ProductCursor INTO @MASP, @TENSP, @SOLUONGTON
    END

    -- Đóng con trỏ và giải phóng tài nguyên
    CLOSE ProductCursor
    DEALLOCATE ProductCursor

    -- Hoàn tất giao dịch
END
GO

-- THÊM ĐƠN ĐẶT HÀNG
CREATE PROCEDURE SP_THEM_DONDATHANG
    @MADDH INT,
    @MASP INT,
    @MANSX INT,
    @SL_DAT INT
AS
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Kiểm tra sản phẩm có tồn tại
        IF NOT EXISTS (SELECT 1 FROM SANPHAM WHERE MASP = @MASP)
        BEGIN
            PRINT N'Lỗi: Sản phẩm không tồn tại!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        -- Kiểm tra nhà sản xuất có tồn tại
        IF NOT EXISTS (SELECT 1 FROM NHASX WHERE MANSX = @MANSX)
        BEGIN
            PRINT N'Lỗi: Nhà sản xuất không tồn tại!';
            ROLLBACK TRANSACTION;
            RETURN;
        END
        -- Kiểm tra số lượng đặt
        DECLARE @SLSPTD INT;
        SELECT @SLSPTD = SLSPTD FROM SANPHAM WHERE MASP = @MASP;
        IF @SL_DAT < (@SLSPTD * 0.1)
        BEGIN
            PRINT N'Lỗi: Số lượng đặt phải lớn hơn hoặc bằng 10% SL-SP-TĐ!';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Thêm đơn đặt hàng mới
        INSERT INTO DONDATHANG (MADDH, MASP, NGAYDATHANG, TRANGTHAI, SL_DAT, MANSX)
        VALUES (@MADDH, @MASP, GETDATE(), N'Đang xử lý', @SL_DAT, @MANSX);

        -- Xác nhận thành công
        PRINT N'Thêm đơn đặt hàng thành công!';
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Xử lý lỗi
        PRINT N'Lỗi xảy ra: ' + ERROR_MESSAGE();
        ROLLBACK TRANSACTION;
    END CATCH
END
GO


-- THÊM VÀO BẢNG NHẬN HÀNG
CREATE PROCEDURE SP_THEM_NHANHANG
    @MADDH INT,
    @MASP INT,
    @SL_NHAN INT,
    @NGAYNHAN DATE
AS
BEGIN
    BEGIN TRANSACTION;

    BEGIN TRY

        -- Kiểm tra mã đơn hàng (MADDH) có tồn tại trong bảng DONDATHANG không
        IF NOT EXISTS (SELECT 1 FROM DONDATHANG WHERE MADDH = @MADDH)
        BEGIN
            RAISERROR ('Mã đơn đặt hàng không tồn tại.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Kiểm tra mã sản phẩm (MASP) có tồn tại trong bảng SANPHAM không
        IF NOT EXISTS (SELECT 1 FROM SANPHAM WHERE MASP = @MASP)
        BEGIN
            RAISERROR ('Mã sản phẩm không tồn tại.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Kiểm tra tính hợp lệ của SL_NHAN
        IF @SL_NHAN <= 0
        BEGIN
            RAISERROR ('Số lượng nhận phải lớn hơn 0.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Kiểm tra SL_NHAN <= SL_DAT
        DECLARE @SL_DAT INT;
        SELECT @SL_DAT = SL_DAT 
        FROM DONDATHANG 
        WHERE MADDH = @MADDH AND MASP = @MASP;

        IF @SL_NHAN > @SL_DAT
        BEGIN
            RAISERROR ('Số lượng nhận vượt quá số lượng đặt.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Thêm dòng vào bảng NHANHANG
        INSERT INTO NHANHANG (MADDH, SL_NHAN, NGAYNHAN)
        VALUES (@MADDH, @SL_NHAN, @NGAYNHAN);

        -- Cập nhật TRANGTHAI trong bảng DONDATHANG
        -- Lấy tổng số lượng đã nhận cho mã đơn đặt hàng và sản phẩm này
        DECLARE @TongSLNhan INT;
        SELECT @TongSLNhan = ISNULL(SUM(SL_NHAN), 0)
        FROM NHANHANG NH
		JOIN DONDATHANG DDH ON NH.MADDH = DDH.MADDH
        WHERE NH.MADDH = @MADDH AND DDH.MASP = @MASP;

        -- Nếu tổng SL_NHAN = SL_DAT, cập nhật trạng thái "Đã giao"
        IF @TongSLNhan = @SL_DAT
        BEGIN
            UPDATE DONDATHANG
            SET TRANGTHAI = N'Đã giao'
            WHERE MADDH = @MADDH AND MASP = @MASP;
        END
        -- Nếu tổng SL_NHAN < SL_DAT, cập nhật trạng thái "Giao thiếu"
        ELSE
        BEGIN
            UPDATE DONDATHANG
            SET TRANGTHAI = N'Giao thiếu'
            WHERE MADDH = @MADDH AND MASP = @MASP;
        END

        -- Cập nhật SOLUONGTON trong bảng SANPHAM
        UPDATE SANPHAM
        SET SOLUONGTON = SOLUONGTON + @SL_NHAN
        WHERE MASP = @MASP;

        -- Thông báo thêm nhận hàng thành công
        PRINT 'Thêm nhận hàng thành công.';

        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH
        -- Xử lý lỗi
        PRINT ERROR_MESSAGE();
        ROLLBACK TRANSACTION;
    END CATCH
END
GO

-- TÍNH TOÁN SỐ HÀNG CẦN ĐẶT CHO CÁC SẢN PHẨM
CREATE PROCEDURE SP_TINHTOAN_SOLUONGDATHANG
AS
BEGIN
    BEGIN TRANSACTION;
    DECLARE @MASP INT, @SL_TON INT, @SL_SP_TD INT, @SL_DA_DAT INT, @SL_GIAO_THIEU INT, @SL_DAT INT;

    -- Khai báo con trỏ để duyệt qua từng sản phẩm trong bảng SANPHAM
    DECLARE product_cursor CURSOR FOR
    SELECT MASP, SOLUONGTON, SLSPTD
    FROM SANPHAM;

    OPEN product_cursor;
    FETCH NEXT FROM product_cursor INTO @MASP, @SL_TON, @SL_SP_TD;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Tính số lượng đã đặt nhưng chưa giao (SL_DA_DAT)
        SELECT @SL_DA_DAT = ISNULL(SUM(SL_DAT), 0)
        FROM DONDATHANG
        WHERE MASP = @MASP AND TRANGTHAI = N'Đang xử lý';

        -- Tính số lượng giao thiếu (SL_GIAO_THIEU)
        SELECT @SL_GIAO_THIEU = ISNULL(SUM(DDH.SL_DAT - NH.SL_NHAN), 0)
        FROM DONDATHANG DDH
		JOIN NHANHANG NH ON DDH.MADDH = NH.MADDH
        WHERE MASP = @MASP AND TRANGTHAI = N'Giao thiếu';

        -- Tính số lượng cần đặt (SL_DAT)
        SET @SL_DAT = @SL_SP_TD - (@SL_TON + @SL_DA_DAT + @SL_GIAO_THIEU);

        -- Kiểm tra các điều kiện của số lượng đặt
        IF @SL_TON < @SL_SP_TD * 0.7 AND @SL_DAT >= @SL_SP_TD * 0.1
        BEGIN
            IF @SL_DAT + @SL_TON <= @SL_SP_TD
            BEGIN
                -- Trả về số lượng cần đặt cho sản phẩm này
                PRINT 'Sản phẩm ' + CAST(@MASP AS VARCHAR) + ' cần đặt: ' + CAST(@SL_DAT AS VARCHAR);
				-- Chỗ này có thể gọi SP_THEM_DONDATHANG luôn
            END
        END

        FETCH NEXT FROM product_cursor INTO @MASP, @SL_TON, @SL_SP_TD;
    END

    CLOSE product_cursor;
    DEALLOCATE product_cursor;

    COMMIT TRANSACTION;
END;
GO

-- Xem lịch sử nhập hàng của 1 sản phẩm cụ thể
CREATE PROCEDURE SP_XemLichSuNhapHang
    @MASP INT
AS
BEGIN
	BEGIN TRANSACTION;
    SELECT MADDH, NGAYDATHANG, SL_DAT, TRANGTHAI
    FROM DONDATHANG
    WHERE MASP = @MASP
    ORDER BY NGAYDATHANG DESC;
	COMMIT TRANSACTION;
    PRINT N'Tra cứu lịch sử nhập hàng thành công!';
END;
GO

-- Hủy đơn đặt hàng
CREATE PROCEDURE SP_HuyDonDatHang
    @MADDH INT
AS
BEGIN
    BEGIN TRANSACTION;
    BEGIN TRY
        -- Kiểm tra trạng thái
        DECLARE @TRANGTHAI NVARCHAR(50);
        SELECT @TRANGTHAI = TRANGTHAI FROM DONDATHANG WHERE MADDH = @MADDH;

        IF @TRANGTHAI = N'Hoàn thành'
        BEGIN
            PRINT N'Lỗi: Không thể xóa đơn đặt hàng đã hoàn thành!';
            ROLLBACK TRANSACTION;
            RETURN;
        END

        -- Xóa đơn đặt hàng
        DELETE FROM DONDATHANG WHERE MADDH = @MADDH;

        PRINT N'Xóa đơn đặt hàng thành công!';
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        PRINT N'Lỗi xảy ra: ' + ERROR_MESSAGE();
        ROLLBACK TRANSACTION;
    END CATCH
END;
GO

-------------------------------------------------------------------------------------------------------
/*BỘ PHẬN KINH DOANH*/
-- Thêm Store Procedure SP_THONGKEBAOCAONGAY
CREATE PROCEDURE SP_THONGKEBAOCAONGAY
AS
BEGIN
    BEGIN TRANSACTION;

    DECLARE @NgayBaoCao DATE = CAST(GETDATE() AS DATE);
    DECLARE @TongKhachHang INT = 0;
    DECLARE @TongDoanhThu DECIMAL(15,2) = 0.00;

    -- Tính tổng số khách hàng trong ngày
    SELECT @TongKhachHang = COUNT(DISTINCT SO_DIEN_THOAI)
    FROM DONHANG
    WHERE CAST(NGAYMUA AS DATE) = @NgayBaoCao;

    -- Tính tổng doanh thu trong ngày
    SELECT @TongDoanhThu = SUM(TONGGIATRI)
    FROM DONHANG
    WHERE CAST(NGAYMUA AS DATE) = @NgayBaoCao;

    -- Cập nhật bảng BAOCAONGAY
    UPDATE BAOCAONGAY
    SET TONGKHACHHANG = @TongKhachHang,
        TONGDOANHTHU = @TongDoanhThu
    WHERE NGAYBAOCAO = @NgayBaoCao;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO BAOCAONGAY (NGAYBAOCAO, TONGKHACHHANG, TONGDOANHTHU)
        VALUES (@NgayBaoCao, @TongKhachHang, @TongDoanhThu);
    END;

    COMMIT TRANSACTION;
END;
GO

-- Thêm Store Procedure SP_THONGKESANPHAM
CREATE PROCEDURE SP_THONGKESANPHAM
AS
BEGIN
    BEGIN TRANSACTION;

    DECLARE @NgayBaoCao DATE = CAST(GETDATE() AS DATE);

    -- Duyệt qua từng sản phẩm
    INSERT INTO BAOCAOSP (NGAYBAOCAO, MASP, SLBAN, SLKHMUA)
    SELECT
        @NgayBaoCao,
        SP.MASP,
        ISNULL(SUM(CTDH.SOLUONG), 0) AS SLBAN,
        COUNT(DISTINCT DH.SO_DIEN_THOAI) AS SLKHMUA
    FROM
        SANPHAM SP
        LEFT JOIN CHITIETDONHANG CTDH ON SP.MASP = CTDH.MASP
        LEFT JOIN DONHANG DH ON CTDH.DONHANGID = DH.DONHANGID
    WHERE
        CAST(DH.NGAYMUA AS DATE) = @NgayBaoCao
    GROUP BY SP.MASP;

    COMMIT TRANSACTION;
END;
GO
