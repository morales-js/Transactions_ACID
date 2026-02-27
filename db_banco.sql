

CREATE DATABASE BancoDB;
GO
USE BancoDB;
GO

---2. CREAR TABLAS---
-- TABLA SUCURSAL
CREATE TABLE Sucursal(
    Id_Sucursal INT PRIMARY KEY,
    Nombre VARCHAR(50),
    Estado BIT
);

-- TABLA USUARIO
CREATE TABLE Usuario(
    Id_Usuario INT PRIMARY KEY,
    Nombre VARCHAR(50),
    Estado BIT
);

-- TABLA MOVIMIENTOS
CREATE TABLE Movimientos(
    Id_Movimiento INT IDENTITY(1,1) PRIMARY KEY,
    Fecha DATE,
    Tipo CHAR(1), -- D = Deposito, R = Retiro
    Monto DECIMAL(10,2),
    Id_Sucursal INT,
    FOREIGN KEY (Id_Sucursal) REFERENCES Sucursal(Id_Sucursal)
);

-- TABLA CIERRE DE CAJA
CREATE TABLE CierreCaja(
    Id_Cierre INT IDENTITY(1,1) PRIMARY KEY,
    Fecha DATE,
    Total_Depositos DECIMAL(10,2),
    Total_Retiros DECIMAL(10,2),
    Saldo_Final DECIMAL(10,2),
    Id_Sucursal INT,
    Id_Usuario INT
);

-- TABLA DE AUDITORÍA (VALOR AGREGADO)
CREATE TABLE LogErrores(
    Id_Log INT IDENTITY(1,1) PRIMARY KEY,
    MensajeError VARCHAR(300),
    Procedimiento VARCHAR(100),
    FechaError DATETIME DEFAULT GETDATE(),
    UsuarioSQL VARCHAR(100)
);

----3. INSERTAR DATOS DE PRUEBA ---
-- Sucursales
INSERT INTO Sucursal VALUES (1,'Sucursal Centro',1);
INSERT INTO Sucursal VALUES (2,'Sucursal Norte',1);

-- Usuarios
INSERT INTO Usuario VALUES (1,'Juan Perez',1);
INSERT INTO Usuario VALUES (2,'Maria Lopez',1);

-- Movimientos
INSERT INTO Movimientos (Fecha,Tipo,Monto,Id_Sucursal) VALUES
('2026-02-24','D',500,1),
('2026-02-24','D',300,1),
('2026-02-24','R',200,1),
('2026-02-24','R',100,1);
GO

--4. PROCEDIMIENTO ALMACENADO COMPLETO---
DROP PROCEDURE sp_cierre_diario_caja;
GO

CREATE PROCEDURE sp_cierre_diario_caja
    @Fecha DATE,
    @IdSucursal INT,
    @IdUsuario INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION

        -- VALIDACIONES
        IF @Fecha > GETDATE()
            THROW 50001, 'La fecha no puede ser futura', 1;

        IF NOT EXISTS (SELECT 1 FROM Sucursal WHERE Id_Sucursal = @IdSucursal)
            THROW 50002, 'La sucursal no existe', 1;

        IF NOT EXISTS (SELECT 1 FROM Usuario WHERE Id_Usuario = @IdUsuario AND Estado = 1)
            THROW 50003, 'Usuario no existe o está inactivo', 1;

        IF EXISTS (SELECT 1 FROM CierreCaja WHERE Fecha=@Fecha AND Id_Sucursal=@IdSucursal)
            THROW 50004, 'Ya existe cierre para esta fecha y sucursal', 1;

        IF NOT EXISTS (SELECT 1 FROM Movimientos WHERE Fecha=@Fecha AND Id_Sucursal=@IdSucursal)
            THROW 50005, 'No existen movimientos para este día', 1;

        -- CALCULOS
        DECLARE @TotalDepositos DECIMAL(10,2)=0;
        DECLARE @TotalRetiros DECIMAL(10,2)=0;

        SELECT @TotalDepositos = ISNULL(SUM(Monto),0)
        FROM Movimientos
        WHERE Fecha=@Fecha AND Tipo='D' AND Id_Sucursal=@IdSucursal;

        SELECT @TotalRetiros = ISNULL(SUM(Monto),0)
        FROM Movimientos
        WHERE Fecha=@Fecha AND Tipo='R' AND Id_Sucursal=@IdSucursal;

        DECLARE @SaldoFinal DECIMAL(10,2)
        SET @SaldoFinal = @TotalDepositos - @TotalRetiros;

        -- INSERTAR CIERRE
        INSERT INTO CierreCaja
        VALUES(@Fecha,@TotalDepositos,@TotalRetiros,@SaldoFinal,@IdSucursal,@IdUsuario);

        COMMIT TRANSACTION
        PRINT 'Cierre realizado correctamente'

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION

        INSERT INTO LogErrores(MensajeError, Procedimiento, UsuarioSQL)
        VALUES(ERROR_MESSAGE(),'sp_cierre_diario_caja',SUSER_SNAME());

        PRINT 'Error registrado en LogErrores'
    END CATCH
END

---5. SEGURIDAD POR ROLES---
-- Crear rol administrador
CREATE ROLE RolAdministrador;

GRANT EXECUTE ON sp_cierre_diario_caja TO RolAdministrador;

DENY EXECUTE ON sp_cierre_diario_caja TO PUBLIC;

-- Dar permiso solo al rol administrador
GRANT EXECUTE ON sp_cierre_diario_caja TO RolAdministrador;

-- Quitar acceso a todos los demás
DENY EXECUTE ON sp_cierre_diario_caja TO PUBLIC;

---6. EJECUTAR EL PROCEDIMIENTO---
EXEC sp_cierre_diario_caja 
    @Fecha='2026-02-24',
    @IdSucursal=1,
    @IdUsuario=1;


    ----7. VER RESULTADOS---
SELECT * FROM CierreCaja;
SELECT * FROM LogErrores;