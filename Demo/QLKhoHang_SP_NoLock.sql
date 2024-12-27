-- USE master
USE SupermarketDB
GO
-- KIỂM TRA TỒN KHO
CREATE PROCEDURE SP_KIEMTRA_TONKHO
AS
BEGIN
	BEGIN TRANSACTION;
    SELECT MASP, TENSP, SOLUONGTON
    FROM SANPHAM
    ORDER BY MASP;
	COMMIT TRANSACTION;
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

    COMMIT;
END;
GO
