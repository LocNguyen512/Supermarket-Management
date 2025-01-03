﻿USE SupermarketDB
GO

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

    PRINT N'Thêm sản phẩm thành công';
END
GO

EXEC SP_THEM_SAN_PHAM 1, N'Áo thun', N'100% cotton', 'SamSung', 100000, N'Thời trang', 500, 300

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

        INSERT INTO SANPHAM_KHUYENMAI (MASP, KHUYENMAIID, SLAPDUNG)
        VALUES (@MASP1, @MAKHUYENMAI, @SOLUONGTOIDA);
    END
    ELSE IF @MALOAIKHUYENMAI = '2' -- COMBO-SALE
    BEGIN
        INSERT INTO SANPHAM_KHUYENMAI (MASP, KHUYENMAIID, SLAPDUNG)
        VALUES (@MASP1, @MAKHUYENMAI, @SOLUONGTOIDA);

        INSERT INTO SANPHAM_KHUYENMAI (MASP, KHUYENMAIID, SLAPDUNG)
        VALUES (@MASP2, @MAKHUYENMAI, @SOLUONGTOIDA);
    END
    ELSE IF @MALOAIKHUYENMAI = '1' -- FLASH-SALE
    BEGIN
        INSERT INTO SANPHAM_KHUYENMAI (MASP, KHUYENMAIID, SLAPDUNG)
        VALUES (@MASP1, @MAKHUYENMAI, @SOLUONGTOIDA);
    END

    PRINT N'THÊM KHUYẾN MÃI THÀNH CÔNG.';
END;

SELECT * FROM SANPHAM
SELECT * FROM KHUYENMAI
SELECT * FROM SANPHAM_KHUYENMAI
SELECT * FROM KHUYENMAI_KHACHHANG
EXEC SP_THEM_KHUYEN_MAI '14', 1, NULL, '1', 50,'2024-12-28','2024-12-30', 200, NULL
EXEC SP_THEM_KHUYEN_MAI '16', 1, 2, '2', 50,'2024-12-28','2024-12-30', 10, NULL
EXEC SP_THEM_KHUYEN_MAI '17', 1, NULL, '3', 50,'2024-12-28','2024-12-30', 20, N'THÂN THIẾT'

-- 3.KIẾM TRA ÁP DỤNG KHUYẾN MÃI
CREATE OR ALTER PROCEDURE SP_KIEMTRA_APDUNG_KHUYENMAI
    @MASP INT,
    @NGAYHIENTAI DATE,
    @MUCKHTT NVARCHAR(50)
AS
BEGIN
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
      AND SPKM.SLAPDUNG > 0;

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
END
GO

EXEC SP_KIEMTRA_APDUNG_KHUYENMAI 1, '2024-12-28', N'THÂN THIẾT'

-- 4. Xóa sản phẩm
CREATE OR ALTER PROCEDURE SP_XOA_SAN_PHAM
    @MASP INT
AS
BEGIN
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

    -- Xóa các thông tin khuyến mãi liên quan đến sản phẩm
    DELETE FROM KHUYENMAI_KHACHHANG
    WHERE MAKHUYENMAI IN (
        SELECT DISTINCT KHUYENMAIID
        FROM SANPHAM_KHUYENMAI
        WHERE MASP = @MASP
    );
    -- Xóa các khuyến mãi liên quan sản phẩm
    DELETE FROM SANPHAM_KHUYENMAI
    WHERE MASP = @MASP;

    DELETE FROM KHUYENMAI
    WHERE MAKHUYENMAI IN (
        SELECT DISTINCT KHUYENMAIID
        FROM SANPHAM_KHUYENMAI
        WHERE MASP = @MASP
    );


    -- Xóa sản phẩm
    DELETE FROM SANPHAM
    WHERE MASP = @MASP;

    PRINT N'Xóa sản phẩm và các khuyến mãi liên quan thành công';
END
GO

EXEC SP_XOA_SAN_PHAM 1

DROP PROCEDURE
    dbo.SP_THEM_SAN_PHAM,
    dbo.SP_THEM_KHUYEN_MAI,
    dbo.SP_KIEMTRA_APDUNG_KHUYENMAI,
	dbo.SP_XOA_SAN_PHAM;