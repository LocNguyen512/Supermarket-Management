﻿USE MASTER
GO
DROP DATABASE SupermarketDB;
GO
CREATE DATABASE SupermarketDB;
GO
USE SupermarketDB;
GO

-- Bảng KHACHHANG
CREATE TABLE KHACHHANG (
    SODIENTHOAI CHAR(10) PRIMARY KEY,
    TENKH NVARCHAR(100) NOT NULL,
    NGAYSINH DATE,
    NGAYDANGKI DATE NOT NULL,
    NGAYXETKHTT DATE,
    MUCKHTT NVARCHAR(50)
);

-- Bảng LSMUAHANG
CREATE TABLE LSMUAHANG (
    SODIENTHOAI CHAR(10) NOT NULL,
    NGAYTHANHTOAN DATETIME NOT NULL,
    THANHTIEN DECIMAL(15,2) NOT NULL,
    FOREIGN KEY (SODIENTHOAI) REFERENCES KHACHHANG(SODIENTHOAI)
);

-- Bảng PHIEUMUAHANG
CREATE TABLE PHIEUMUAHANG (
    MAPHIEUMUAHANG CHAR(8) PRIMARY KEY,
    SODIENTHOAI CHAR(10) NOT NULL,
    NGAYHIEULUC DATE NOT NULL,
    NGAYHETHAN DATE NOT NULL,
    GIATRI DECIMAL(15,2) NOT NULL,
    TRANGTHAI NVARCHAR(50) NOT NULL,
    FOREIGN KEY (SODIENTHOAI) REFERENCES KHACHHANG(SODIENTHOAI)
);

-- Bảng DANHMUC
CREATE TABLE DANHMUC (
    MADANHMUC INT PRIMARY KEY,
    TENDANHMUC NVARCHAR(50) NOT NULL
);

-- Bảng SANPHAM
CREATE TABLE SANPHAM (
    MASP INT PRIMARY KEY,
    TENSP NVARCHAR(255) NOT NULL,
    MOTA NVARCHAR(200),
    MANSX INT,
    GIA DECIMAL(15,2) NOT NULL,
    MADANHMUC INT,
    SLSPTD INT NOT NULL,
    SOLUONGTON INT NOT NULL CHECK (SOLUONGTON >= 0),
    FOREIGN KEY (MADANHMUC) REFERENCES DANHMUC(MADANHMUC)
);

-- Bảng NHASX
CREATE TABLE NHASX (
    MANSX INT PRIMARY KEY,
    TENNSX NVARCHAR(100) NOT NULL,
    SDT CHAR(10)
);

-- Bảng KHUYENMAI
CREATE TABLE KHUYENMAI (
    MAKHUYENMAI NVARCHAR(50) PRIMARY KEY,
    MALOAIKHUYENMAI INT NOT NULL CHECK (MALOAIKHUYENMAI IN (1, 2, 3)),
    TYLEGIAM FLOAT,
    NGAYBATDAU DATE NOT NULL,
    NGAYKETTHUC DATE NOT NULL,
    SOLUONGTOIDA INT NOT NULL
);

-- Bảng SANPHAM_KHUYENMAI
CREATE TABLE SANPHAM_KHUYENMAI (
    MASP INT NOT NULL,
    KHUYENMAIID NVARCHAR(50) NOT NULL,
    FOREIGN KEY (MASP) REFERENCES SANPHAM(MASP),
    FOREIGN KEY (KHUYENMAIID) REFERENCES KHUYENMAI(MAKHUYENMAI), 
	PRIMARY KEY(MASP, KHUYENMAIID)
);

-- Bảng KHUYENMAI_KHACHHANG
CREATE TABLE KHUYENMAI_KHACHHANG (
    MAKHUYENMAI NVARCHAR(50) NOT NULL,
    MUCKHTT NVARCHAR(50) NOT NULL,
    TYLEGIAM FLOAT NOT NULL,
    FOREIGN KEY (MAKHUYENMAI) REFERENCES KHUYENMAI(MAKHUYENMAI),
	PRIMARY KEY(MAKHUYENMAI, MUCKHTT)
);

-- Bảng DONHANG
CREATE TABLE DONHANG (
    DONHANGID NVARCHAR(50) PRIMARY KEY,
    SO_DIEN_THOAI CHAR(10) NOT NULL,
    NGAYMUA DATETIME NOT NULL,
    TONGGIATRI DECIMAL(15,2),
    FOREIGN KEY (SO_DIEN_THOAI) REFERENCES KHACHHANG(SODIENTHOAI)
);

-- Bảng CHITIETDONHANG
CREATE TABLE CHITIETDONHANG (
    DONHANGID NVARCHAR(50) NOT NULL,
    MASP INT NOT NULL,
    SOLUONG INT NOT NULL,
    GIASAPDUNG DECIMAL(15,2),
    KHUYENMAIID NVARCHAR(50),
    FOREIGN KEY (DONHANGID) REFERENCES DONHANG(DONHANGID),
    FOREIGN KEY (MASP) REFERENCES SANPHAM(MASP),
    FOREIGN KEY (KHUYENMAIID) REFERENCES KHUYENMAI(MAKHUYENMAI)
);

-- Bảng DONDATHANG
CREATE TABLE DONDATHANG (
    MADDH NVARCHAR(50) PRIMARY KEY,
    MASP INT NOT NULL,
    NGAYDATHANG DATE NOT NULL,
    TRANGTHAI NVARCHAR(50) NOT NULL,
    SL_DAT INT NOT NULL CHECK (SL_DAT > 0),
	MANSX INT NOT NULL
	FOREIGN KEY (MANSX) REFERENCES NHASX(MANSX),
    FOREIGN KEY (MASP) REFERENCES SANPHAM(MASP)
);

-- Bảng NHANHANG
CREATE TABLE NHANHANG (
    MANH NVARCHAR(50) PRIMARY KEY,
    MADDH NVARCHAR(50) NOT NULL,
    NGAYNHAN DATE NOT NULL,
    SL_NHAN INT NOT NULL CHECK (SL_NHAN >= 0),
    FOREIGN KEY (MADDH) REFERENCES DONDATHANG(MADDH)
);

-- Bảng BAOCAONGAY
CREATE TABLE BAOCAONGAY (
    NGAYBAOCAO DATE PRIMARY KEY,
    TONGKHACHHANG INT DEFAULT 0,
    TONGDOANHTHU DECIMAL(15,2) DEFAULT 0.00
);

-- Bảng BAOCAOSP
CREATE TABLE BAOCAOSP (
    NGAYBAOCAO DATE NOT NULL,
    MASP INT NOT NULL,
    SLBAN INT DEFAULT 0,
    SLKHMUA INT DEFAULT 0,
    PRIMARY KEY (NGAYBAOCAO, MASP),
    FOREIGN KEY (MASP) REFERENCES SANPHAM(MASP)
);
