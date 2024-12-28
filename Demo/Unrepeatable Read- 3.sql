USE SupermarketDB;
GO

-- 
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

EXEC SP_TIM_KHUYEN_MAI_TOT_NHAT '5'
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
EXEC SP_SUATHONGTINLIENLAC '0900000005', N'Cha Eun Woo','0900000111', N'Cha Eun Woo', '1995-04-10';
SELECT* FROM khachhang;