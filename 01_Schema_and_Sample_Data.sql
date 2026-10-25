-- =====================================================================
--  NKO'S DRIVING SCHOOL  |  MySQL 8.0+ (MySQL Workbench)
--  Script 01: Create database, 16 tables, constraints, sample data
-- =====================================================================

DROP DATABASE IF EXISTS nkos_driving_school;
CREATE DATABASE nkos_driving_school CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE nkos_driving_school;

-- ---------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------

CREATE TABLE Branch (
    BranchID        INT AUTO_INCREMENT PRIMARY KEY,
    BranchName      VARCHAR(50) NOT NULL,
    Suburb          VARCHAR(50) NOT NULL,
    ContactNumber   VARCHAR(15) NULL,
    CONSTRAINT UQ_Branch_Name UNIQUE (BranchName)
);

CREATE TABLE Licence_Category (
    CategoryCode            VARCHAR(5) PRIMARY KEY,
    CategoryName            VARCHAR(30) NOT NULL,
    VehicleClassDescription VARCHAR(100) NULL,
    CONSTRAINT CK_Category_Code CHECK (CategoryCode IN ('08','10','11','14'))
);

CREATE TABLE Learner (
    CellphoneNumber     VARCHAR(15) PRIMARY KEY,
    FirstName           VARCHAR(50) NOT NULL,
    Surname             VARCHAR(50) NOT NULL,
    TargetCategoryCode  VARCHAR(5)  NOT NULL,
    RegistrationDate    DATE        NOT NULL,
    CONSTRAINT FK_Learner_Category FOREIGN KEY (TargetCategoryCode)
        REFERENCES Licence_Category(CategoryCode)
);

CREATE TABLE Administrator (
    AdminID         INT AUTO_INCREMENT PRIMARY KEY,
    FirstName       VARCHAR(50) NOT NULL,
    Surname         VARCHAR(50) NOT NULL,
    ContactNumber   VARCHAR(15) NULL,
    CONSTRAINT UQ_Admin_Contact UNIQUE (ContactNumber)      -- MySQL allows many NULLs
);

CREATE TABLE Instructor_Driver (
    DriverID        INT AUTO_INCREMENT PRIMARY KEY,
    FirstName       VARCHAR(50) NOT NULL,
    Surname         VARCHAR(50) NOT NULL,
    ContactNumber   VARCHAR(15) NULL,
    BranchID        INT NOT NULL,
    CONSTRAINT UQ_Driver_Contact UNIQUE (ContactNumber),
    CONSTRAINT FK_Driver_Branch FOREIGN KEY (BranchID) REFERENCES Branch(BranchID)
);

CREATE TABLE Vehicle (
    VehicleRegistration VARCHAR(15) PRIMARY KEY,
    CategoryCode        VARCHAR(5) NOT NULL,
    BranchID            INT NOT NULL,
    CONSTRAINT FK_Vehicle_Category FOREIGN KEY (CategoryCode) REFERENCES Licence_Category(CategoryCode),
    CONSTRAINT FK_Vehicle_Branch   FOREIGN KEY (BranchID)     REFERENCES Branch(BranchID)
);

-- Business Rules 7 & 8: two drivers per vehicle, only ONE Active per day.
-- MySQL has no filtered unique index, so a generated column is used instead:
-- ActiveKey = 1 for Active rows and NULL otherwise (NULLs never clash in a UNIQUE index).
CREATE TABLE Vehicle_Driver_Roster (
    RosterID            INT AUTO_INCREMENT PRIMARY KEY,
    VehicleRegistration VARCHAR(15) NOT NULL,
    DriverID            INT NOT NULL,
    RosterDate          DATE NOT NULL,
    RoleForDay          VARCHAR(10) NOT NULL,
    AssignmentStatus    VARCHAR(10) NOT NULL,
    ActiveKey           TINYINT GENERATED ALWAYS AS (IF(AssignmentStatus = 'Active', 1, NULL)) STORED,
    CONSTRAINT FK_Roster_Vehicle FOREIGN KEY (VehicleRegistration) REFERENCES Vehicle(VehicleRegistration),
    CONSTRAINT FK_Roster_Driver  FOREIGN KEY (DriverID)            REFERENCES Instructor_Driver(DriverID),
    CONSTRAINT CK_Roster_Role    CHECK (RoleForDay IN ('Lesson','Test')),
    CONSTRAINT CK_Roster_Status  CHECK (AssignmentStatus IN ('Active','Potential','Inactive')),
    CONSTRAINT UQ_Roster_Entry   UNIQUE (VehicleRegistration, DriverID, RosterDate),
    CONSTRAINT UX_Roster_OneActiveDriverPerVehicleDay UNIQUE (VehicleRegistration, RosterDate, ActiveKey)
);

CREATE TABLE Training_Package (
    PackageID           INT AUTO_INCREMENT PRIMARY KEY,
    CategoryCode        VARCHAR(5) NOT NULL,
    PackageName         VARCHAR(60) NOT NULL,
    NumberOfLessons     INT NOT NULL,
    Price               DECIMAL(10,2) NOT NULL,
    IncludesVehicleHire TINYINT(1) NOT NULL DEFAULT 0,
    PackageType         VARCHAR(20) NOT NULL,
    ValidityMonths      INT NULL,
    CONSTRAINT UQ_Package_Name UNIQUE (PackageName),
    CONSTRAINT FK_Package_Category FOREIGN KEY (CategoryCode) REFERENCES Licence_Category(CategoryCode),
    CONSTRAINT CK_Package_Lessons CHECK (NumberOfLessons > 0),
    CONSTRAINT CK_Training_Package_Price CHECK (Price > 0),
    CONSTRAINT CK_Package_Type CHECK (PackageType IN ('Standard','Refresher','Computerised'))
);

CREATE TABLE Learner_Package (
    LearnerPackageID    INT AUTO_INCREMENT PRIMARY KEY,
    CellphoneNumber     VARCHAR(15) NOT NULL,
    PackageID           INT NOT NULL,
    PurchaseDate        DATE NOT NULL,
    LessonsUsed         INT NOT NULL DEFAULT 0,
    OutstandingBalance  DECIMAL(10,2) NOT NULL,
    Status              VARCHAR(15) NOT NULL DEFAULT 'Active',
    CONSTRAINT FK_LP_Learner FOREIGN KEY (CellphoneNumber) REFERENCES Learner(CellphoneNumber)
        ON UPDATE CASCADE,                      -- a changed cellphone number cascades (see report s.12.2)
    CONSTRAINT FK_LP_Package FOREIGN KEY (PackageID) REFERENCES Training_Package(PackageID),
    CONSTRAINT CK_LP_Used    CHECK (LessonsUsed >= 0),
    CONSTRAINT CK_LP_Balance CHECK (OutstandingBalance >= 0),
    CONSTRAINT CK_LP_Status  CHECK (Status IN ('Active','Suspended','Completed'))
);

CREATE TABLE Booking (
    BookingID                INT AUTO_INCREMENT PRIMARY KEY,
    LearnerPackageID         INT NOT NULL,
    RequestedDate            DATE NOT NULL,
    ScheduledLessonDate      DATE NOT NULL,
    ScheduledStartTime       TIME NOT NULL,
    Status                   VARCHAR(15) NOT NULL DEFAULT 'Confirmed',
    CancellationReason       VARCHAR(100) NULL,
    CancellationDateTime     DATETIME NULL,
    BookingCreatedByAdminID  INT NOT NULL,
    CONSTRAINT FK_Booking_LP    FOREIGN KEY (LearnerPackageID) REFERENCES Learner_Package(LearnerPackageID),
    CONSTRAINT FK_Booking_Admin FOREIGN KEY (BookingCreatedByAdminID) REFERENCES Administrator(AdminID),
    CONSTRAINT CK_Booking_Status CHECK (Status IN ('Confirmed','Cancelled','Completed')),
    CONSTRAINT CK_Booking_Cancellation CHECK (
        (Status <> 'Cancelled' AND CancellationDateTime IS NULL) OR
        (Status =  'Cancelled' AND CancellationDateTime IS NOT NULL))
);

CREATE TABLE Lesson (
    LessonID            INT AUTO_INCREMENT PRIMARY KEY,
    BookingID           INT NOT NULL,
    DriverID            INT NOT NULL,
    VehicleRegistration VARCHAR(15) NOT NULL,
    LessonDate          DATE NOT NULL,
    StartTime           TIME NOT NULL,
    EndTime             TIME NOT NULL,
    KmBefore            INT NULL,
    KmAfter             INT NULL,
    LearnerCoSigned     TINYINT(1) NOT NULL DEFAULT 0,
    LessonStatus        VARCHAR(15) NOT NULL DEFAULT 'Completed',
    CONSTRAINT UQ_Lesson_Booking UNIQUE (BookingID),                       -- Booking 1 : 0..1 Lesson
    CONSTRAINT UX_Lesson_DriverSlot UNIQUE (DriverID, LessonDate, StartTime),
    CONSTRAINT FK_Lesson_Booking FOREIGN KEY (BookingID) REFERENCES Booking(BookingID),
    CONSTRAINT FK_Lesson_Driver  FOREIGN KEY (DriverID)  REFERENCES Instructor_Driver(DriverID),
    CONSTRAINT FK_Lesson_Vehicle FOREIGN KEY (VehicleRegistration) REFERENCES Vehicle(VehicleRegistration),
    CONSTRAINT CK_Lesson_Time    CHECK (EndTime > StartTime),
    CONSTRAINT CK_Lesson_Km      CHECK (KmAfter IS NULL OR KmBefore IS NULL OR KmAfter >= KmBefore),
    CONSTRAINT CK_Lesson_Status  CHECK (LessonStatus IN ('Completed','No-Show','Cancelled'))
);

CREATE TABLE Payment (
    PaymentID           INT AUTO_INCREMENT PRIMARY KEY,
    LearnerPackageID    INT NOT NULL,
    AmountPaid          DECIMAL(10,2) NOT NULL,
    PaymentDate         DATE NOT NULL,
    PaymentMethod       VARCHAR(20) NOT NULL,
    ProofOfPaymentRef   VARCHAR(50) NOT NULL,
    BankUsed            VARCHAR(20) NULL,
    VerifiedByAdminID   INT NOT NULL,
    CONSTRAINT UQ_Payment_POP UNIQUE (ProofOfPaymentRef),
    CONSTRAINT FK_Payment_LP    FOREIGN KEY (LearnerPackageID) REFERENCES Learner_Package(LearnerPackageID),
    CONSTRAINT FK_Payment_Admin FOREIGN KEY (VerifiedByAdminID) REFERENCES Administrator(AdminID),
    CONSTRAINT CK_Payment_Amount CHECK (AmountPaid > 0),
    CONSTRAINT CK_Payment_Method CHECK (PaymentMethod IN ('EFT','Bank Deposit','Electronic Transfer'))  -- no cash
);

CREATE TABLE Test_Registration (
    TestRegistrationID  INT AUTO_INCREMENT PRIMARY KEY,
    CellphoneNumber     VARCHAR(15) NOT NULL,
    CategoryCode        VARCHAR(5)  NOT NULL,
    RegistrationDate    DATE NOT NULL,
    EyeTestCompleted    TINYINT(1) NOT NULL DEFAULT 0,
    RegistrationStatus  VARCHAR(20) NOT NULL DEFAULT 'Pending',
    CONSTRAINT FK_TR_Learner  FOREIGN KEY (CellphoneNumber) REFERENCES Learner(CellphoneNumber)
        ON UPDATE CASCADE,
    CONSTRAINT FK_TR_Category FOREIGN KEY (CategoryCode) REFERENCES Licence_Category(CategoryCode),
    CONSTRAINT CK_TR_Status   CHECK (RegistrationStatus IN ('Pending','Registered','Completed','Cancelled'))
);

CREATE TABLE Test_Attempt (
    TestAttemptID           INT AUTO_INCREMENT PRIMARY KEY,
    LearnerPackageID        INT NOT NULL,
    AttemptNumber           INT NOT NULL,
    TestDate                DATE NOT NULL,
    TestingDepartment       VARCHAR(60) NOT NULL,
    Outcome                 VARCHAR(10) NULL,
    AdditionalFeeCharged    TINYINT(1) NOT NULL DEFAULT 0,
    VehicleRegistration     VARCHAR(15) NOT NULL,
    AccompanyingDriverID    INT NOT NULL,
    CONSTRAINT UQ_Attempt_Number UNIQUE (LearnerPackageID, AttemptNumber),
    CONSTRAINT FK_TA_LP      FOREIGN KEY (LearnerPackageID) REFERENCES Learner_Package(LearnerPackageID),
    CONSTRAINT FK_TA_Vehicle FOREIGN KEY (VehicleRegistration) REFERENCES Vehicle(VehicleRegistration),
    CONSTRAINT FK_TA_Driver  FOREIGN KEY (AccompanyingDriverID) REFERENCES Instructor_Driver(DriverID),
    CONSTRAINT CK_TA_Number  CHECK (AttemptNumber >= 1),
    CONSTRAINT CK_TA_Outcome CHECK (Outcome IS NULL OR Outcome IN ('Pass','Fail')),
    CONSTRAINT CK_Test_Attempt_Fee CHECK (AttemptNumber <= 3 OR AdditionalFeeCharged = 1)
);

CREATE TABLE Vehicle_Maintenance (
    MaintenanceID       INT AUTO_INCREMENT PRIMARY KEY,
    VehicleRegistration VARCHAR(15) NOT NULL,
    ServiceDate         DATE NOT NULL,
    KmAtService         INT NOT NULL,
    NextServiceDueKm    INT NOT NULL,
    NextServiceDueDate  DATE NULL,
    CONSTRAINT FK_Maint_Vehicle FOREIGN KEY (VehicleRegistration) REFERENCES Vehicle(VehicleRegistration),
    CONSTRAINT CK_Vehicle_Maintenance_KM CHECK (NextServiceDueKm >= KmAtService + 10000)
);

CREATE TABLE Vehicle_Odometer_Log (
    OdometerLogID       INT AUTO_INCREMENT PRIMARY KEY,
    VehicleRegistration VARCHAR(15) NOT NULL,
    LogDate             DATE NOT NULL,
    OdometerReading     INT NOT NULL,
    RecordedByAdminID   INT NOT NULL,
    CONSTRAINT UQ_Odometer_VehicleDay UNIQUE (VehicleRegistration, LogDate),   -- one reading per vehicle per day
    CONSTRAINT FK_Odo_Vehicle FOREIGN KEY (VehicleRegistration) REFERENCES Vehicle(VehicleRegistration),
    CONSTRAINT FK_Odo_Admin   FOREIGN KEY (RecordedByAdminID)   REFERENCES Administrator(AdminID)
);

-- ---------------------------------------------------------------------
-- 2. TRIGGERS (needed before lesson data goes in)
-- ---------------------------------------------------------------------
DELIMITER $$

-- Rule 10: one-hour lessons with a 30-minute gap (driver AND vehicle)
CREATE TRIGGER trg_Lesson_BeforeInsert_Gap
BEFORE INSERT ON Lesson
FOR EACH ROW
BEGIN
    IF NEW.LessonStatus <> 'Cancelled' AND EXISTS (
        SELECT 1 FROM Lesson l
        WHERE l.LessonDate = NEW.LessonDate
          AND l.LessonStatus <> 'Cancelled'
          AND (l.DriverID = NEW.DriverID OR l.VehicleRegistration = NEW.VehicleRegistration)
          AND TIME_TO_SEC(NEW.StartTime) < TIME_TO_SEC(l.EndTime)   + 1800
          AND TIME_TO_SEC(NEW.EndTime)   > TIME_TO_SEC(l.StartTime) - 1800
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Clash: driver or vehicle already in use, lessons need a 30-minute gap (Rule 10).';
    END IF;
END$$

-- Rule 20: log the closing odometer reading whenever a completed lesson is recorded
CREATE TRIGGER trg_AfterLessonOdometerLog
AFTER INSERT ON Lesson
FOR EACH ROW
BEGIN
    IF NEW.LessonStatus = 'Completed' AND NEW.KmAfter IS NOT NULL THEN
        INSERT INTO Vehicle_Odometer_Log (VehicleRegistration, LogDate, OdometerReading, RecordedByAdminID)
        SELECT NEW.VehicleRegistration, NEW.LessonDate, NEW.KmAfter, b.BookingCreatedByAdminID
        FROM Booking b WHERE b.BookingID = NEW.BookingID
        ON DUPLICATE KEY UPDATE OdometerReading = GREATEST(OdometerReading, NEW.KmAfter);
    END IF;
END$$

-- Rule 18: attempts must be consecutive; no attempts after a pass; 4th+ attempt must be chargeable
CREATE TRIGGER trg_ValidateTestAttempt
BEFORE INSERT ON Test_Attempt
FOR EACH ROW
BEGIN
    DECLARE v_last INT;
    DECLARE v_passed INT;
    SELECT COALESCE(MAX(AttemptNumber),0), COALESCE(SUM(Outcome = 'Pass'),0)
      INTO v_last, v_passed
      FROM Test_Attempt WHERE LearnerPackageID = NEW.LearnerPackageID;

    IF NEW.AttemptNumber <> v_last + 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error 50030: test attempts must be numbered consecutively.';
    END IF;
    IF v_passed > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Learner has already passed on this package; no further attempts allowed.';
    END IF;
    IF NEW.AttemptNumber > 3 AND NEW.AdditionalFeeCharged = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error 50031: a fourth or later attempt must be flagged as chargeable.';
    END IF;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- 3. SAMPLE DATA: reference data
-- ---------------------------------------------------------------------
INSERT INTO Branch (BranchName, Suburb, ContactNumber) VALUES
 ('Delft Branch','Delft','0215550101'),
 ('Langa Branch','Langa','0215550202');

INSERT INTO Licence_Category VALUES
 ('08','Light Vehicle','Light motor vehicles (cars, bakkies up to 3 500 kg)'),
 ('10','Medium Rigid Vehicle','Medium rigid vehicles'),
 ('11','Heavy Rigid Vehicle','Heavy rigid vehicles'),
 ('14','Articulated Vehicle','Articulated vehicles and truck-trailer combinations');

INSERT INTO Administrator (FirstName, Surname, ContactNumber) VALUES
 ('Nomsa','Dlamini','0821110001'),
 ('Kabelo','Mokoena','0821110002');

INSERT INTO Instructor_Driver (FirstName, Surname, ContactNumber, BranchID) VALUES
 ('Sizwe','Ndlovu','0831230001',1),
 ('Lerato','Khumalo','0831230002',1),
 ('Bongani','Zulu','0831230003',1),
 ('Ayanda','Mthembu','0831230004',2),
 ('Zanele','Naidoo','0831230005',2),
 ('Themba','Sithole','0831230006',2);

-- Rule 6: each branch has 2 x Code 08, 2 x Code 10, 1 x Code 11, 1 x Code 14
INSERT INTO Vehicle VALUES
 ('CA 123-001','08',1),('CA 123-002','08',1),('CA 123-003','10',1),
 ('CA 123-004','10',1),('CA 123-005','11',1),('CA 123-006','14',1),
 ('CA 456-001','08',2),('CA 456-002','08',2),('CA 456-003','10',2),
 ('CA 456-004','10',2),('CA 456-005','11',2),('CA 456-006','14',2);

INSERT INTO Training_Package (PackageID, CategoryCode, PackageName, NumberOfLessons, Price, IncludesVehicleHire, PackageType, ValidityMonths) VALUES
 (1,'08','Code 08 Basic - 6 Lessons',            6, 1800.00,0,'Standard',3),
 (2,'08','Code 08 Full - 10 Lessons + Car Hire',10, 3200.00,1,'Standard',6),
 (3,'08','Code 08 Refresher - 3 Lessons',        3,  950.00,0,'Refresher',2),
 (4,'10','Code 10 Full - 12 Lessons',           12, 4800.00,1,'Standard',6),
 (5,'11','Code 11 Heavy - 15 Lessons',          15, 6500.00,1,'Standard',6),
 (6,'14','Code 14 Truck - 20 Lessons',          20, 9000.00,1,'Standard',9),
 (7,'08','Code 08 Computerised - 8 Lessons',     8, 2400.00,0,'Computerised',4);

-- ---------------------------------------------------------------------
-- 4. SAMPLE DATA: learners, packages, payments
-- ---------------------------------------------------------------------
INSERT INTO Learner VALUES
 ('0823000001','Sipho','Jele','08','2026-07-01'),
 ('0823000002','Lindiwe','Mabaso','08','2026-07-02'),
 ('0823000003','Musa','Khan','10','2026-07-03'),
 ('0823000004','Anele','Dube','11','2026-07-05'),
 ('0823000005','Thandi','Mthethwa','14','2026-07-06'),
 ('0823000006','Kagiso','Petersen','08','2026-07-08'),
 ('0823000007','Naledi','Williams','08','2026-07-10'),
 ('0823000008','Farhan','Abrahams','10','2026-07-12');

-- Final state of each purchase after the seeded history below has run
INSERT INTO Learner_Package (LearnerPackageID, CellphoneNumber, PackageID, PurchaseDate, LessonsUsed, OutstandingBalance, Status) VALUES
 ( 1,'0823000001',1,'2026-07-02',0,   0.00,'Completed'),
 ( 2,'0823000001',2,'2026-08-01',0,1600.00,'Active'),     -- Rule 17: Sipho buys a second package
 ( 3,'0823000002',1,'2026-07-03',0, 900.00,'Suspended'),  -- Rule 15: balance owed, half the lessons used
 ( 4,'0823000003',1,'2026-07-04',0,   0.00,'Completed'),
 ( 5,'0823000003',4,'2026-07-25',0,   0.00,'Active'),
 ( 6,'0823000004',1,'2026-07-06',0,   0.00,'Completed'),
 ( 7,'0823000004',5,'2026-07-25',0,2000.00,'Active'),
 ( 8,'0823000005',1,'2026-07-07',0,   0.00,'Completed'),
 ( 9,'0823000005',6,'2026-07-16',0,   0.00,'Completed'),
 (10,'0823000006',1,'2026-07-09',0,   0.00,'Completed'),
 (11,'0823000007',3,'2026-07-11',0,   0.00,'Completed'),
 (12,'0823000008',1,'2026-07-13',0,   0.00,'Completed'),
 (13,'0823000008',4,'2026-07-30',0,3000.00,'Suspended');  -- paid R1800 of R4800, 6 of 12 lessons used

INSERT INTO Payment (LearnerPackageID, AmountPaid, PaymentDate, PaymentMethod, ProofOfPaymentRef, BankUsed, VerifiedByAdminID) VALUES
 ( 1,1800.00,'2026-07-02','EFT','POP-0001','FNB',1),
 ( 2,1600.00,'2026-08-01','Electronic Transfer','POP-0002','FNB',2),
 ( 3, 900.00,'2026-07-03','Bank Deposit','POP-0003','Capitec',1),
 ( 4,1800.00,'2026-07-04','EFT','POP-0004','Standard Bank',2),
 ( 5,2400.00,'2026-07-25','EFT','POP-0005','Standard Bank',2),
 ( 5,2400.00,'2026-08-02','EFT','POP-0006','Standard Bank',1),
 ( 6,1800.00,'2026-07-06','Bank Deposit','POP-0007','Absa',1),
 ( 7,4500.00,'2026-07-25','EFT','POP-0008','Absa',2),
 ( 8,1800.00,'2026-07-07','EFT','POP-0009','Nedbank',1),
 ( 9,5000.00,'2026-07-16','EFT','POP-0010','Nedbank',1),
 ( 9,4000.00,'2026-07-18','EFT','POP-0011','Nedbank',2),
 (10,1800.00,'2026-07-09','Electronic Transfer','POP-0012','Capitec',2),
 (11, 950.00,'2026-07-11','EFT','POP-0013','FNB',1),
 (12,1800.00,'2026-07-13','Bank Deposit','POP-0014','Capitec',2),
 (13,1800.00,'2026-07-30','EFT','POP-0015','Capitec',1);

-- ---------------------------------------------------------------------
-- 5. SAMPLE DATA: lesson history (generated by a temporary helper)
--    Creates N completed bookings + lessons, one per gap-days, 1 hour each,
--    35 km per lesson; the odometer trigger fills Vehicle_Odometer_Log.
-- ---------------------------------------------------------------------
DELIMITER $$
CREATE PROCEDURE tmp_SeedHistory(
    IN p_lpid INT, IN p_n INT, IN p_start DATE, IN p_gap INT, IN p_driver INT,
    IN p_vehicle VARCHAR(15), IN p_basekm INT, IN p_time TIME, IN p_admin INT)
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE d DATE;
    DECLARE km INT;
    DECLARE bid INT;
    DECLARE pdate DATE;
    SELECT PurchaseDate INTO pdate FROM Learner_Package WHERE LearnerPackageID = p_lpid;
    SELECT COALESCE(MAX(KmAfter), p_basekm) INTO km FROM Lesson WHERE VehicleRegistration = p_vehicle;
    WHILE i < p_n DO
        SET d = DATE_ADD(p_start, INTERVAL i * p_gap DAY);
        INSERT INTO Booking (LearnerPackageID, RequestedDate, ScheduledLessonDate, ScheduledStartTime, Status, BookingCreatedByAdminID)
        VALUES (p_lpid, GREATEST(pdate, DATE_SUB(d, INTERVAL 7 DAY)), d, p_time, 'Completed', p_admin);
        SET bid = LAST_INSERT_ID();
        INSERT INTO Lesson (BookingID, DriverID, VehicleRegistration, LessonDate, StartTime, EndTime, KmBefore, KmAfter, LearnerCoSigned, LessonStatus)
        VALUES (bid, p_driver, p_vehicle, d, p_time, ADDTIME(p_time,'01:00:00'), km, km + 35, 1, 'Completed');
        SET km = km + 35;
        SET i = i + 1;
    END WHILE;
    UPDATE Learner_Package SET LessonsUsed = LessonsUsed + p_n WHERE LearnerPackageID = p_lpid;
END$$
DELIMITER ;

--              lpid n  start         gap driver vehicle       baseKm time      admin
-- Delft learners
CALL tmp_SeedHistory( 1, 6,'2026-07-06', 1, 1,'CA 123-001', 40800,'08:00:00',1);   -- Sipho basics
CALL tmp_SeedHistory( 4, 6,'2026-07-08', 1, 2,'CA 123-002', 97400,'09:30:00',2);   -- Musa basics
CALL tmp_SeedHistory( 6, 6,'2026-07-14', 1, 1,'CA 123-001', 40800,'08:00:00',1);   -- Anele basics
CALL tmp_SeedHistory( 3, 3,'2026-07-20', 2, 2,'CA 123-002', 97400,'09:30:00',1);   -- Lindiwe basics (half used)
CALL tmp_SeedHistory( 5, 5,'2026-08-03', 2, 3,'CA 123-003', 70000,'10:00:00',2);   -- Musa Code 10
CALL tmp_SeedHistory( 7, 3,'2026-08-05', 3, 3,'CA 123-005', 30100,'12:00:00',1);   -- Anele Code 11
CALL tmp_SeedHistory( 2, 2,'2026-08-10', 2, 1,'CA 123-001', 40800,'08:00:00',2);   -- Sipho Full package (2 of 10)
-- Langa learners
CALL tmp_SeedHistory( 8, 6,'2026-07-09', 1, 4,'CA 456-001', 63000,'08:00:00',2);   -- Thandi basics
CALL tmp_SeedHistory(10, 6,'2026-07-13', 1, 5,'CA 456-002', 20000,'08:00:00',1);   -- Kagiso basics
CALL tmp_SeedHistory(11, 3,'2026-07-15', 2, 4,'CA 456-001', 63000,'08:00:00',2);   -- Naledi refresher
CALL tmp_SeedHistory(12, 6,'2026-07-20', 1, 6,'CA 456-001', 63000,'08:00:00',1);   -- Farhan basics
CALL tmp_SeedHistory( 9,20,'2026-07-20', 1, 5,'CA 456-006', 72000,'09:00:00',2);   -- Thandi Code 14
CALL tmp_SeedHistory(13, 6,'2026-08-12', 1, 6,'CA 456-003', 65100,'09:00:00',1);   -- Farhan Code 10 (half used)

DROP PROCEDURE tmp_SeedHistory;

-- A few edge cases added by hand
INSERT INTO Booking (BookingID, LearnerPackageID, RequestedDate, ScheduledLessonDate, ScheduledStartTime, Status, CancellationReason, CancellationDateTime, BookingCreatedByAdminID) VALUES
 (1001, 2,'2026-09-25','2026-10-02','10:00:00','Cancelled','Learner unwell','2026-10-01 18:00:00',1),   -- cancelled booking
 (1002, 2,'2026-09-30','2026-10-09','08:00:00','Confirmed',NULL,NULL,1),                                 -- upcoming lesson
 (1003, 5,'2026-08-05','2026-08-13','08:00:00','Completed',NULL,NULL,2);                                 -- no-show booking

INSERT INTO Lesson (BookingID, DriverID, VehicleRegistration, LessonDate, StartTime, EndTime, KmBefore, KmAfter, LearnerCoSigned, LessonStatus)
VALUES (1003, 3,'CA 123-003','2026-08-13','08:00:00','09:00:00',NULL,NULL,0,'No-Show');                 -- no-show lesson

-- Daily roster for 10 Aug 2026 (one Active driver per vehicle, the other rostered for test/hire duty)
INSERT INTO Vehicle_Driver_Roster (VehicleRegistration, DriverID, RosterDate, RoleForDay, AssignmentStatus) VALUES
 ('CA 123-001',1,'2026-08-10','Lesson','Active'),('CA 123-001',2,'2026-08-10','Test','Potential'),
 ('CA 123-002',2,'2026-08-10','Lesson','Active'),('CA 123-002',3,'2026-08-10','Test','Potential'),
 ('CA 123-003',3,'2026-08-10','Lesson','Active'),('CA 123-003',1,'2026-08-10','Test','Potential'),
 ('CA 456-001',4,'2026-08-10','Lesson','Active'),('CA 456-001',5,'2026-08-10','Test','Potential'),
 ('CA 456-003',5,'2026-08-10','Lesson','Active'),('CA 456-003',6,'2026-08-10','Test','Potential');

-- Tests: Kagiso passes first time; Naledi fails 3 times then passes on a chargeable 4th; Thandi fails then passes
INSERT INTO Test_Registration (CellphoneNumber, CategoryCode, RegistrationDate, EyeTestCompleted, RegistrationStatus) VALUES
 ('0823000006','08','2026-08-01',1,'Completed'),
 ('0823000007','08','2026-08-01',1,'Completed'),
 ('0823000005','14','2026-08-15',1,'Completed'),
 ('0823000003','10','2026-09-01',1,'Registered'),
 ('0823000004','11','2026-09-05',0,'Pending'),
 ('0823000008','10','2026-09-10',1,'Registered');

INSERT INTO Test_Attempt (LearnerPackageID, AttemptNumber, TestDate, TestingDepartment, Outcome, AdditionalFeeCharged, VehicleRegistration, AccompanyingDriverID) VALUES
 (10,1,'2026-08-10','Delft Traffic Department','Pass',0,'CA 456-002',5),
 (11,1,'2026-08-12','Langa Traffic Department','Fail',0,'CA 456-001',4),
 (11,2,'2026-08-19','Langa Traffic Department','Fail',0,'CA 456-001',4),
 (11,3,'2026-08-26','Langa Traffic Department','Fail',0,'CA 456-001',4),
 (11,4,'2026-09-02','Langa Traffic Department','Pass',1,'CA 456-001',4),   -- 4th attempt: chargeable
 ( 9,1,'2026-08-20','Langa Traffic Department','Fail',0,'CA 456-006',5),
 ( 9,2,'2026-08-27','Langa Traffic Department','Pass',0,'CA 456-006',5);

-- Services (CA 456-002 deliberately has NO service history)
INSERT INTO Vehicle_Maintenance (VehicleRegistration, ServiceDate, KmAtService, NextServiceDueKm, NextServiceDueDate) VALUES
 ('CA 123-001','2026-04-10',40000,50000,'2026-12-10'),
 ('CA 123-002','2026-03-15',88000,98000,'2026-09-15'),
 ('CA 123-003','2026-05-02',65000,75000,'2026-11-02'),
 ('CA 123-004','2026-04-20',45000,55000,'2026-12-20'),
 ('CA 123-005','2026-05-22',28000,38000,'2026-12-22'),
 ('CA 123-006','2026-03-30',55000,65000,'2026-10-30'),
 ('CA 456-001','2026-02-12',54000,64000,'2026-08-12'),
 ('CA 456-003','2026-05-18',65000,75000,'2026-11-18'),
 ('CA 456-004','2026-06-01',75000,85000,'2026-12-01'),
 ('CA 456-005','2026-04-25',35000,45000,'2026-10-25'),
 ('CA 456-006','2026-05-11',66000,76000,'2026-11-11');

-- Latest manual odometer readings for vehicles that had no lessons
INSERT INTO Vehicle_Odometer_Log (VehicleRegistration, LogDate, OdometerReading, RecordedByAdminID) VALUES
 ('CA 123-002','2026-09-15',98139,1),   -- past its service-due reading -> SERVICE OVERDUE
 ('CA 123-004','2026-09-15',51044,1),
 ('CA 123-006','2026-09-15',63000,2),
 ('CA 456-004','2026-09-15',80150,2),
 ('CA 456-005','2026-09-15',41000,2);

-- ---------------------------------------------------------------------
-- 6. VERIFICATION
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS TotalTables
FROM information_schema.tables
WHERE table_schema = 'nkos_driving_school' AND table_type = 'BASE TABLE';

SELECT COUNT(*) AS TotalForeignKeys
FROM information_schema.table_constraints
WHERE table_schema = 'nkos_driving_school' AND constraint_type = 'FOREIGN KEY';

SELECT 'Branch' AS TableName, COUNT(*) AS Row_Count FROM Branch
UNION ALL SELECT 'Licence_Category', COUNT(*) FROM Licence_Category
UNION ALL SELECT 'Learner', COUNT(*) FROM Learner
UNION ALL SELECT 'Administrator', COUNT(*) FROM Administrator
UNION ALL SELECT 'Instructor_Driver', COUNT(*) FROM Instructor_Driver
UNION ALL SELECT 'Vehicle', COUNT(*) FROM Vehicle
UNION ALL SELECT 'Vehicle_Driver_Roster', COUNT(*) FROM Vehicle_Driver_Roster
UNION ALL SELECT 'Training_Package', COUNT(*) FROM Training_Package
UNION ALL SELECT 'Learner_Package', COUNT(*) FROM Learner_Package
UNION ALL SELECT 'Booking', COUNT(*) FROM Booking
UNION ALL SELECT 'Lesson', COUNT(*) FROM Lesson
UNION ALL SELECT 'Payment', COUNT(*) FROM Payment
UNION ALL SELECT 'Test_Registration', COUNT(*) FROM Test_Registration
UNION ALL SELECT 'Test_Attempt', COUNT(*) FROM Test_Attempt
UNION ALL SELECT 'Vehicle_Maintenance', COUNT(*) FROM Vehicle_Maintenance
UNION ALL SELECT 'Vehicle_Odometer_Log', COUNT(*) FROM Vehicle_Odometer_Log;
