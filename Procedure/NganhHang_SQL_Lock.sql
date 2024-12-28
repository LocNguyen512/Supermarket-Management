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
    BEGIN TRANSACTION;

    -- Đặt mức cô lập giao dịch là SERIALIZABLE
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    -- Kiểm tra mã sản phẩm phải chưa tồn tại
    IF EXISTS (
        SELECT 1
        FROM SANPHAM WITH (HOLDLOCK)
        WHERE MASP = @MASP
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR (N'Mã sản phẩm đã tồn tại.', 16, 1);
        RETURN;
    END

    -- Xác định mã nhà sản xuất dựa trên tên nhà sản xuất
    DECLARE @MANSX INT;
    SELECT @MANSX = MANSX
    FROM NHASX WITH (REPEATABLEREAD)
    WHERE TENNSX = @TENNSX;

    IF @MANSX IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR (N'NHÀ SẢN XUẤT KHÔNG TỒN TẠI', 16, 1);
        RETURN;
    END

    -- Xác định mã danh mục dựa trên tên danh mục
    DECLARE @MADANHMUC INT;
    SELECT @MADANHMUC = MADANHMUC
    FROM DANHMUC WITH (REPEATABLEREAD)
    WHERE TENDANHMUC = @TENDANHMUC;

    IF @MADANHMUC IS NULL
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR (N'DANH MỤC KHÔNG TÔN TẠI', 16, 1);
        RETURN;
    END

    -- Thêm sản phẩm vào bảng SANPHAM
    INSERT INTO SANPHAM (MASP, TENSP, MOTA, MANSX, GIA, MADANHMUC, SLSPTD, SOLUONGTON)
    VALUES (@MASP, @TENSP, @MOTA, @MANSX, @GIA, @MADANHMUC, @SLSPTD, @SLTK);

    COMMIT TRANSACTION;
    PRINT N'Thêm sản phẩm thành công';
END

EXEC SP_THEM_SAN_PHAM 1, N'Áo thun', N'100% cotton', 'SamSung', 100000, N'Thời trang', 500, 300

-- 2.XÓA SẢN PHẨM
CREATE PROCEDURE SP_XOA_SAN_PHAM
    @MASP INT
AS
BEGIN
    BEGIN TRANSACTION;

    -- Đặt mức cô lập giao dịch là REPEATABLE READ
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    -- Kiểm tra mã sản phẩm phải tồn tại
    IF NOT EXISTS (
        SELECT 1
        FROM SANPHAM WITH (REPEATABLEREAD)
        WHERE MASP = @MASP
    )
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR (N'Mã sản phẩm không tồn tại.', 16, 1);
        RETURN;
    END

    -- Xóa các thông tin khuyến mãi liên quan đến sản phẩm
    DELETE FROM KHUYENMAI_KHACHHANG
    WHERE MAKHUYENMAI IN (
        SELECT DISTINCT KHUYENMAIID
        FROM SANPHAM_KHUYENMAI WITH (REPEATABLEREAD)
        WHERE MASP = @MASP
    );

    DELETE FROM KHUYENMAI
    WHERE MAKHUYENMAI IN (
        SELECT DISTINCT KHUYENMAIID
        FROM SANPHAM_KHUYENMAI WITH (REPEATABLEREAD)
        WHERE MASP = @MASP
    );

    -- Xóa các khuyến mãi liên quan sản phẩm
    DELETE FROM SANPHAM_KHUYENMAI
    WHERE MASP = @MASP;

    -- Xóa sản phẩm
    DELETE FROM SANPHAM
    WHERE MASP = @MASP;

    COMMIT TRANSACTION;
    PRINT N'Xóa sản phẩm và các khuyến mãi liên quan thành công';
END

EXEC SP_XOA_SAN_PHAM 1

-- 3.Thêm khuyến mãi 
CREATE PROCEDURE SP_THEM_KHUYEN_MAI 
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
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    -- Kiểm tra mã khuyến mãi có tồn tại không
    IF EXISTS (
        SELECT 1 FROM KHUYENMAI WITH (HOLDLOCK)
        WHERE MAKHUYENMAI = @MAKHUYENMAI
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50001, N'MÃ KHUYẾN MÃI ĐÃ TỒN TẠI', 1;
    END

    -- Kiểm tra sản phẩm có tồn tại không
    IF NOT EXISTS (
        SELECT 1 FROM SANPHAM WITH (REPEATABLEREAD)
        WHERE MASP = @MASP1
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50002, N'MÃ SẢN PHẨM KHÔNG TỒN TẠI', 1;
    END

    IF @MASP2 IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM SANPHAM WITH (REPEATABLEREAD)
        WHERE MASP = @MASP2
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50003, N'MÃ SẢN PHẨM THỨ HAI KHÔNG TỒN TẠI', 1;
    END

    -- Kiểm tra tồn kho
    DECLARE @SLTON1 INT;
    SELECT @SLTON1 = SOLUONGTON FROM SANPHAM WITH (HOLDLOCK) WHERE MASP = @MASP1;

    IF @SOLUONGTOIDA > @SLTON1
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50004, N'KHO KHÔNG ĐỦ SỐ LƯỢNG SẢN PHẨM', 1;
    END

    IF @MASP2 IS NOT NULL
    BEGIN
		IF @MUCKHTT NOT IN (N'THÂN THIẾT', N'ĐỒNG', N'BẠC', N'VÀNG', N'KIM CƯƠNG')
        BEGIN
            THROW 50006, N'HẠNG KHÁCH HÀNG KHÔNG PHÙ HỢP', 1;
        END
        DECLARE @SLTON2 INT;
        SELECT @SLTON2 = SOLUONGTON FROM SANPHAM WITH (HOLDLOCK) WHERE MASP = @MASP2;

        IF @SOLUONGTOIDA > @SLTON2
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 50004, N'KHO KHÔNG ĐỦ SỐ LƯỢNG SẢN PHẨM THỨ HAI', 1;
        END
    END

    -- Kiểm tra loại khuyến mãi
    IF @MALOAIKHUYENMAI NOT IN ('1', '2', '3') 
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50005, N'LOẠI KHUYẾN MÃI KHÔNG PHÙ HỢP', 1;
    END

    -- Thêm khuyến mãi vào bảng KHUYENMAI
    INSERT INTO KHUYENMAI WITH (XLOCK) (MAKHUYENMAI, MALOAIKHUYENMAI, TYLEGIAM, NGAYBATDAU, NGAYKETTHUC, SOLUONGTOIDA)
    VALUES (@MAKHUYENMAI, @MALOAIKHUYENMAI, @TYLEGIAM, @NGAYBATDAU, @NGAYKETTHUC, @SOLUONGTOIDA);

    -- Xử lý từng loại khuyến mãi
    IF @MALOAIKHUYENMAI = '3' -- MEMBER-SALE
    BEGIN
        IF @MUCKHTT NOT IN (N'THÂN THIẾT', N'ĐỒNG', N'BẠC', N'VÀNG', N'KIM CƯƠNG')
        BEGIN
            ROLLBACK TRANSACTION;
            THROW 50006, N'HẠNG KHÁCH HÀNG KHÔNG PHÙ HỢP', 1;
        END

        INSERT INTO KHUYENMAI_KHACHHANG WITH (XLOCK) (MAKHUYENMAI, MUCKHTT, TYLEGIAM)
        VALUES (@MAKHUYENMAI, @MUCKHTT, @TYLEGIAM);

        INSERT INTO SANPHAM_KHUYENMAI WITH (XLOCK) (MASP, KHUYENMAIID, SLAPDUNG)
        VALUES (@MASP1, @MAKHUYENMAI, @SOLUONGTOIDA);
    END
    ELSE IF @MALOAIKHUYENMAI = '2' -- COMBO-SALE
    BEGIN
        INSERT INTO SANPHAM_KHUYENMAI WITH (XLOCK) (MASP, KHUYENMAIID, SLAPDUNG)
        VALUES (@MASP1, @MAKHUYENMAI, @SOLUONGTOIDA);

        INSERT INTO SANPHAM_KHUYENMAI WITH (XLOCK) (MASP, KHUYENMAIID, SLAPDUNG)
        VALUES (@MASP2, @MAKHUYENMAI, @SOLUONGTOIDA);
    END
    ELSE IF @MALOAIKHUYENMAI = '1' -- FLASH-SALE
    BEGIN
        INSERT INTO SANPHAM_KHUYENMAI WITH (XLOCK) (MASP, KHUYENMAIID, SLAPDUNG)
        VALUES (@MASP1, @MAKHUYENMAI, @SOLUONGTOIDA);
    END

    COMMIT TRANSACTION;
    PRINT N'THÊM KHUYẾN MÃI THÀNH CÔNG.';
END

EXEC SP_THEM_KHUYEN_MAI '18', 1, NULL, '1', 50,'2024-12-28','2024-12-30', 200, NULL
EXEC SP_THEM_KHUYEN_MAI '19', 1, 2, '2', 50,'2024-12-28','2024-12-30', 10, NULL
EXEC SP_THEM_KHUYEN_MAI '20', 1, NULL, '3', 50,'2024-12-28','2024-12-30', 20, N'THÂN THIẾT'

-- 4. kiểm tra áp dụng khuyến mãi
CREATE PROCEDURE SP_KIEMTRA_APDUNG_KHUYENMAI
    @MASP INT,
    @NGAYHIENTAI DATE,
    @MUCKHTT NVARCHAR(50)
AS
BEGIN
    BEGIN TRANSACTION;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    -- Kiểm tra sản phẩm có hợp lệ không
    IF NOT EXISTS (SELECT 1 FROM SANPHAM WITH (REPEATABLEREAD) WHERE MASP = @MASP)
    BEGIN
        ROLLBACK TRANSACTION;
        RAISERROR (N'SẢN PHẨM KHÔNG HỢP LỆ', 16, 1);
        RETURN;
    END

    -- Kiểm tra mức khách hàng thân thiết có hợp lệ không
    IF @MUCKHTT NOT IN (N'THÂN THIẾT', N'ĐỒNG', N'BẠC', N'VÀNG', N'KIM CƯƠNG')
    BEGIN
        ROLLBACK TRANSACTION;
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
    FROM KHUYENMAI KM WITH (REPEATABLEREAD)
    INNER JOIN SANPHAM_KHUYENMAI SPKM WITH (HOLDLOCK) ON KM.MAKHUYENMAI = SPKM.KHUYENMAIID
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
            FROM KHUYENMAI_KHACHHANG WITH (REPEATABLEREAD)
            WHERE MAKHUYENMAI = @MAKHUYENMAI AND MUCKHTT = @MUCKHTT;

            IF @TYLEGIAM_MEMBER IS NOT NULL
            BEGIN
                INSERT INTO #KHUYENMAI_THONGTIN (TENCHUONGTRINH, NGAYBATDAU, NGAYKETTHUC, LOAIKM, TYLEGIAM)
                SELECT KM.MAKHUYENMAI, KM.NGAYBATDAU, KM.NGAYKETTHUC, 'membersale', @TYLEGIAM_MEMBER
                FROM KHUYENMAI KM WITH (REPEATABLEREAD)
                WHERE KM.MAKHUYENMAI = @MAKHUYENMAI;
            END
        END
        ELSE IF @LOAIKM IN ('1', '2') -- Combo-sale or Flash-sale
        BEGIN
            INSERT INTO #KHUYENMAI_THONGTIN (TENCHUONGTRINH, NGAYBATDAU, NGAYKETTHUC, LOAIKM, TYLEGIAM)
            SELECT KM.MAKHUYENMAI, KM.NGAYBATDAU, KM.NGAYKETTHUC,
                   CASE WHEN @LOAIKM = '1' THEN 'flash-sale' ELSE 'combo-sale' END, @TYLEGIAM
            FROM KHUYENMAI KM WITH (REPEATABLEREAD)
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

EXEC SP_KIEMTRA_APDUNG_KHUYENMAI 1, '2024-12-28', N'THÂN THIẾT'

-- 5. Xóa khuyến mãi
CREATE PROCEDURE SP_XOA_KHUYEN_MAI
AS
BEGIN
    DECLARE @MAKHUYENMAI INT;

    -- Lặp qua tất cả các chương trình khuyến mãi
    DECLARE CUR_KHUYENMAI CURSOR FOR
    SELECT MAKHUYENMAI
    FROM KHUYENMAI
    WHERE NGAYKETTHUC < GETDATE();

    OPEN CUR_KHUYENMAI;

    FETCH NEXT FROM CUR_KHUYENMAI INTO @MAKHUYENMAI;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Xóa các thông tin sản phẩm khuyến mãi
        DELETE FROM SANPHAM_KHUYENMAI
        WHERE KHUYENMAIID = @MAKHUYENMAI;

        -- Xóa các thông tin khuyến mãi cho khách hàng
        DELETE FROM KHUYENMAI_KHACHHANG
        WHERE MAKHUYENMAI = @MAKHUYENMAI;

        -- Xóa khuyến mãi
        DELETE FROM KHUYENMAI
        WHERE MAKHUYENMAI = @MAKHUYENMAI;

        FETCH NEXT FROM CUR_KHUYENMAI INTO @MAKHUYENMAI;
    END

    CLOSE CUR_KHUYENMAI;
    DEALLOCATE CUR_KHUYENMAI;

    PRINT N'Xóa khuyến mãi thành công';
END

EXEC SP_XOA_KHUYEN_MAI
SELECT * FROM KHUYENMAI

-- 6. Thêm danh mục
CREATE PROCEDURE SP_THEM_DANH_MUC
    @MADANHMUC INT,
    @TENDANHMUC NVARCHAR(50)
AS
BEGIN
    -- Kiểm tra mã danh mục đã tồn tại chưa
    IF EXISTS (SELECT 1 FROM DANHMUC WHERE MADANHMUC = @MADANHMUC)
    BEGIN
        RAISERROR (N'MÃ DANH MỤC ĐÃ TỒN TẠI', 16, 1);
        RETURN;
    END

    -- Kiểm tra tên danh mục đã tồn tại chưa
    IF EXISTS (SELECT 1 FROM DANHMUC WHERE TENDANHMUC = @TENDANHMUC)
    BEGIN
        RAISERROR (N'TÊN DANH MỤC ĐÃ TỒN TẠI', 16, 1);
        RETURN;
    END

    -- Thêm danh mục
    INSERT INTO DANHMUC (MADANHMUC, TENDANHMUC)
    VALUES (@MADANHMUC, @TENDANHMUC);

    PRINT N'CẬP NHẬT THÀNH CÔNG';
END

EXEC SP_THEM_DANH_MUC 51, N'Nội thất nhà cửa'

-- 7. Xóa danh mục
CREATE PROCEDURE SP_XOA_DANH_MUC
    @MADANHMUC INT
AS
BEGIN
    -- Kiểm tra mã danh mục đã tồn tại chưa
    IF NOT EXISTS (SELECT 1 FROM DANHMUC WHERE MADANHMUC = @MADANHMUC)
    BEGIN
        RAISERROR (N'MÃ DANH MỤC KHÔNG TỒN TẠI', 16, 1);
        RETURN;
    END

    -- Xóa danh mục
    DELETE FROM DANHMUC WHERE MADANHMUC = @MADANHMUC;

    PRINT N'XÓA DANH MỤC THÀNH CÔNG';
END

EXEC SP_XOA_DANH_MUC 51

-- 8. Cập nhật khuyến mãi
CREATE OR ALTER PROCEDURE  SP_CAPNHAT_KHUYEN_MAI
    @MAKHUYENMAI NVARCHAR(50),
    @NGAYKETTHUC_MOI DATE,
    @SOLUONG_APDUNG INT = NULL
AS
BEGIN
    -- Kiểm tra mã khuyến mãi có tồn tại chưa
    IF NOT EXISTS (SELECT 1 FROM KHUYENMAI WHERE MAKHUYENMAI = @MAKHUYENMAI)
    BEGIN
        RAISERROR (N'MÃ KHUYẾN MÃI KHÔNG TỒN TẠI', 16, 1);
        RETURN;
    END

    -- Kiểm tra ngày khuyến mãi mới có lớn hơn hoặc bằng ngày hiện tại không
    IF @NGAYKETTHUC_MOI < GETDATE()
    BEGIN
        RAISERROR (N'NGÀY KẾT THÚC MỚI PHẢI LỚN HƠN HOẶC BẰNG NGÀY HIỆN TẠI', 16, 1);
        RETURN;
    END

    -- Kiểm tra số lượng áp dụng mới nếu không null
    IF @SOLUONG_APDUNG IS NOT NULL
    BEGIN
        DECLARE @MASP INT, @SLTON INT;

        SELECT TOP 1 @MASP = SP.MASP, @SLTON = SOLUONGTON
        FROM SANPHAM_KHUYENMAI SPKM
        INNER JOIN SANPHAM SP ON SPKM.MASP = SP.MASP
        WHERE SPKM.KHUYENMAIID = @MAKHUYENMAI;

        IF @SOLUONG_APDUNG > @SLTON
        BEGIN
            RAISERROR (N'SỐ LƯỢNG ÁP DỤNG MỚI KHÔNG ĐƯỢC LỚN HƠN SỐ LƯỢNG TỒN KHO', 16, 1);
            RETURN;
        END

        -- Cập nhật số lượng áp dụng mới
        UPDATE SANPHAM_KHUYENMAI
        SET SLAPDUNG = @SOLUONG_APDUNG
        WHERE KHUYENMAIID = @MAKHUYENMAI;
		UPDATE KHUYENMAI
        SET SOLUONGTOIDA = @SOLUONG_APDUNG
        WHERE MAKHUYENMAI = @MAKHUYENMAI;
    END

    -- Cập nhật ngày kết thúc khuyến mãi mới cho chương trình khuyến mãi
    UPDATE KHUYENMAI
    SET NGAYKETTHUC = @NGAYKETTHUC_MOI
    WHERE MAKHUYENMAI = @MAKHUYENMAI;

    PRINT N'CẬP NHẬT KHUYẾN MÃI THÀNH CÔNG';
END

SELECT * FROM KHUYENMAI
EXEC SP_CAPNHAT_KHUYEN_MAI 14, '2025-1-1', 400

