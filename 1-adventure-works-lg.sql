-- AdventureWorks for Postgres
--  by Lorin Thwaits

-- How to use this script:

-- Download "Adventure Works 2014 OLTP Script" from:
--   https://msftdbprodsamples.codeplex.com/downloads/get/880662

-- Extract the .zip and copy all of the CSV files into the same folder containing
-- this install.sql file and the update_csvs.rb file.

-- Modify the CSVs to work with Postgres by running:
--   ruby update_csvs.rb

-- Create the database and tables, import the data, and set up the views and keys with:
--   psql -c "CREATE DATABASE \"Adventureworks\";"
--   psql -d Adventureworks < install.sql

-- All 68 tables are properly set up.
-- All 20 views are established.
-- 68 additional convenience views are added which:
--   * Provide a shorthand to refer to tables.
--   * Add an "id" column to a primary key or primary-ish key if it makes sense.
--
--   For example, with the convenience views you can simply do:
--       SELECT pe.p.firstname, hr.e.jobtitle
--       FROM pe.p
--         INNER JOIN hr.e ON pe.p.id = hr.e.id;
--   Instead of:
--       SELECT p.firstname, e.jobtitle
--       FROM Adventure.person AS p
--         INNER JOIN adventure.employee AS e ON p.businessentityid = e.businessentityid;
--
-- Schemas for these views:
--   pe = person
--   hr = humanresources
--   pr = adventure.
--   pu = purchasing
--   sa = sales
-- Easily get a list of all of these with:  \dv (pe|hr|pr|pu|sa).*

-- Enjoy!


-- -- Disconnect all other existing connections
-- SELECT pg_terminate_backend(pid)
--   FROM pg_stat_activity
--   WHERE pid <> pg_backend_pid() AND datname='Adventureworks';

\pset tuples_only on

-- Support to auto-generate UUIDs (aka GUIDs)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Support crosstab function to do PIVOT thing for Adventure.vSalesPersonSalesByFiscalYears
CREATE EXTENSION IF NOT EXISTS tablefunc;

-------------------------------------
-- Custom data types
-------------------------------------


-------------------------------------
-- Five schemas, with tables and data
-------------------------------------

CREATE SCHEMA Adventure
  CREATE TABLE BusinessEntity(
    BusinessEntityID SERIAL, --  NOT FOR REPLICATION
    rowguid uuid NOT NULL CONSTRAINT "DF_BusinessEntity_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_BusinessEntity_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE Person(
    BusinessEntityID INT NOT NULL,
    PersonType char(2) NOT NULL,
    NameStyle "NameStyle" NOT NULL CONSTRAINT "DF_Person_NameStyle" DEFAULT (false),
    Title varchar(8) NULL,
    FirstName "Name" NOT NULL,
    MiddleName "Name" NULL,
    LastName "Name" NOT NULL,
    Suffix varchar(10) NULL,
    EmailPromotion INT NOT NULL CONSTRAINT "DF_Person_EmailPromotion" DEFAULT (0),
    AdditionalContactInfo XML NULL, -- XML("AdditionalContactInfoSchemaCollection"),
    Demographics XML NULL, -- XML("IndividualSurveySchemaCollection"),
    rowguid uuid NOT NULL CONSTRAINT "DF_Person_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Person_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_Person_EmailPromotion" CHECK (EmailPromotion BETWEEN 0 AND 2),
    CONSTRAINT "CK_Person_PersonType" CHECK (PersonType IS NULL OR UPPER(PersonType) IN ('SC', 'VC', 'IN', 'EM', 'SP', 'GC'))
  )
  CREATE TABLE StateProvince(
    StateProvinceID SERIAL,
    StateProvinceCode char(3) NOT NULL,
    CountryRegionCode varchar(3) NOT NULL,
    IsOnlyStateProvinceFlag "Flag" NOT NULL CONSTRAINT "DF_StateProvince_IsOnlyStateProvinceFlag" DEFAULT (true),
    Name "Name" NOT NULL,
    TerritoryID INT NOT NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_StateProvince_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_StateProvince_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE Address(
    AddressID SERIAL, --  NOT FOR REPLICATION
    AddressLine1 varchar(60) NOT NULL,
    AddressLine2 varchar(60) NULL,
    City varchar(30) NOT NULL,
    StateProvinceID INT NOT NULL,
    PostalCode varchar(15) NOT NULL,
    SpatialLocation bytea NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_Address_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Address_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE AddressType(
    AddressTypeID SERIAL,
    Name "Name" NOT NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_AddressType_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_AddressType_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE BusinessEntityAddress(
    BusinessEntityID INT NOT NULL,
    AddressID INT NOT NULL,
    AddressTypeID INT NOT NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_BusinessEntityAddress_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_BusinessEntityAddress_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE ContactType(
    ContactTypeID SERIAL,
    Name "Name" NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ContactType_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE BusinessEntityContact(
    BusinessEntityID INT NOT NULL,
    PersonID INT NOT NULL,
    ContactTypeID INT NOT NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_BusinessEntityContact_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_BusinessEntityContact_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE EmailAddress(
    BusinessEntityID INT NOT NULL,
    EmailAddressID SERIAL,
    EmailAddress varchar(50) NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_EmailAddress_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_EmailAddress_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE Password(
    BusinessEntityID INT NOT NULL,
    PasswordHash VARCHAR(128) NOT NULL,
    PasswordSalt VARCHAR(10) NOT NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_Password_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Password_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE PhoneNumberType(
    PhoneNumberTypeID SERIAL,
    Name "Name" NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_PhoneNumberType_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE PersonPhone(
    BusinessEntityID INT NOT NULL,
    PhoneNumber "Phone" NOT NULL,
    PhoneNumberTypeID INT NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_PersonPhone_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE CountryRegion(
    CountryRegionCode varchar(3) NOT NULL,
    Name "Name" NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_CountryRegion_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE Department(
    DepartmentID SERIAL NOT NULL, -- smallint
    Name "Name" NOT NULL,
    GroupName "Name" NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Department_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE Employee(
    BusinessEntityID INT NOT NULL,
    NationalIDNumber varchar(15) NOT NULL,
    LoginID varchar(256) NOT NULL,    
    Org varchar NULL,-- hierarchyid, will become OrganizationNode
    OrganizationLevel INT NULL, -- AS OrganizationNode.GetLevel(),
    JobTitle varchar(50) NOT NULL,
    BirthDate DATE NOT NULL,
    MaritalStatus char(1) NOT NULL,
    Gender char(1) NOT NULL,
    HireDate DATE NOT NULL,
    SalariedFlag "Flag" NOT NULL CONSTRAINT "DF_Employee_SalariedFlag" DEFAULT (true),
    VacationHours smallint NOT NULL CONSTRAINT "DF_Employee_VacationHours" DEFAULT (0),
    SickLeaveHours smallint NOT NULL CONSTRAINT "DF_Employee_SickLeaveHours" DEFAULT (0),
    CurrentFlag "Flag" NOT NULL CONSTRAINT "DF_Employee_CurrentFlag" DEFAULT (true),
    rowguid uuid NOT NULL CONSTRAINT "DF_Employee_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Employee_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_Employee_BirthDate" CHECK (BirthDate BETWEEN '1930-01-01' AND NOW() - INTERVAL '18 years'),
    CONSTRAINT "CK_Employee_MaritalStatus" CHECK (UPPER(MaritalStatus) IN ('M', 'S')), -- Married or Single
    CONSTRAINT "CK_Employee_HireDate" CHECK (HireDate BETWEEN '1996-07-01' AND NOW() + INTERVAL '1 day'),
    CONSTRAINT "CK_Employee_Gender" CHECK (UPPER(Gender) IN ('M', 'F')), -- Male or Female
    CONSTRAINT "CK_Employee_VacationHours" CHECK (VacationHours BETWEEN -40 AND 240),
    CONSTRAINT "CK_Employee_SickLeaveHours" CHECK (SickLeaveHours BETWEEN 0 AND 120)
  )
  CREATE TABLE EmployeeDepartmentHistory(
    BusinessEntityID INT NOT NULL,
    DepartmentID smallint NOT NULL,
    ShiftID smallint NOT NULL, -- tinyint
    StartDate DATE NOT NULL,
    EndDate DATE NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_EmployeeDepartmentHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_EmployeeDepartmentHistory_EndDate" CHECK ((EndDate >= StartDate) OR (EndDate IS NULL))
  )
  CREATE TABLE EmployeePayHistory(
    BusinessEntityID INT NOT NULL,
    RateChangeDate TIMESTAMP NOT NULL,
    Rate numeric NOT NULL, -- money
    PayFrequency smallint NOT NULL,  -- tinyint
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_EmployeePayHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_EmployeePayHistory_PayFrequency" CHECK (PayFrequency IN (1, 2)), -- 1 = monthly salary, 2 = biweekly salary
    CONSTRAINT "CK_EmployeePayHistory_Rate" CHECK (Rate BETWEEN 6.50 AND 200.00)
  )
  CREATE TABLE JobCandidate(
    JobCandidateID SERIAL NOT NULL, -- int
    BusinessEntityID INT NULL,
    Resume XML NULL, -- XML(HRResumeSchemaCollection)
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_JobCandidate_ModifiedDate" DEFAULT (NOW())
  )
  CREATE TABLE Shift(
    ShiftID SERIAL NOT NULL, -- tinyint
    Name "Name" NOT NULL,
    StartTime time NOT NULL,
    EndTime time NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Shift_ModifiedDate" DEFAULT (NOW())
  );

COMMENT ON SCHEMA Adventure IS 'Contains objects related to names and addresses of customers, vendors, and employees';

-- Calculated column that needed to be there just for the CSV import
ALTER TABLE Adventure.Employee DROP COLUMN OrganizationLevel;

-- Employee HierarchyID column
ALTER TABLE Adventure.Employee ADD organizationnode VARCHAR DEFAULT '/';
-- Convert from all the hex to a stream of hierarchyid bits
WITH RECURSIVE hier AS (
  SELECT businessentityid, org, get_byte(decode(substring(org, 1, 2), 'hex'), 0)::bit(8)::varchar AS bits, 2 AS i
    FROM Adventure.Employee
  UNION ALL
  SELECT e.businessentityid, e.org, hier.bits || get_byte(decode(substring(e.org, i + 1, 2), 'hex'), 0)::bit(8)::varchar, i + 2 AS i
    FROM Adventure.Employee AS e INNER JOIN
      hier ON e.businessentityid = hier.businessentityid AND i < LENGTH(e.org)
)
UPDATE Adventure.Employee AS emp
  SET org = COALESCE(trim(trailing '0' FROM hier.bits::TEXT), '')
  FROM hier
  WHERE emp.businessentityid = hier.businessentityid
    AND (hier.org IS NULL OR i = LENGTH(hier.org));

-- Convert bits to the real hieararchy paths
CREATE OR REPLACE FUNCTION f_ConvertOrgNodes()
  RETURNS void AS
$func$
DECLARE
  got_none BOOLEAN;
BEGIN
  LOOP
  got_none := true;
  -- 01 = 0-3
  UPDATE Adventure.Employee
   SET organizationnode = organizationnode || SUBSTRING(org, 3,2)::bit(2)::INTEGER::VARCHAR || CASE SUBSTRING(org, 5, 1) WHEN '0' THEN '.' ELSE '/' END,
     org = SUBSTRING(org, 6, 9999)
    WHERE org LIKE '01%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 100 = 4-7
  UPDATE Adventure.Employee
   SET organizationnode = organizationnode || (SUBSTRING(org, 4,2)::bit(2)::INTEGER + 4)::VARCHAR || CASE SUBSTRING(org, 6, 1) WHEN '0' THEN '.' ELSE '/' END,
     org = SUBSTRING(org, 7, 9999)
    WHERE org LIKE '100%';
  IF FOUND THEN
    got_none := false;
  END IF;
  
  -- 101 = 8-15
  UPDATE Adventure.Employee
   SET organizationnode = organizationnode || (SUBSTRING(org, 4,3)::bit(3)::INTEGER + 8)::VARCHAR || CASE SUBSTRING(org, 7, 1) WHEN '0' THEN '.' ELSE '/' END,
     org = SUBSTRING(org, 8, 9999)
    WHERE org LIKE '101%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 110 = 16-79
  UPDATE Adventure.Employee
   SET organizationnode = organizationnode || ((SUBSTRING(org, 4,2)||SUBSTRING(org, 7,1)||SUBSTRING(org, 9,3))::bit(6)::INTEGER + 16)::VARCHAR || CASE SUBSTRING(org, 12, 1) WHEN '0' THEN '.' ELSE '/' END,
     org = SUBSTRING(org, 13, 9999)
    WHERE org LIKE '110%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 1110 = 80-1103
  UPDATE Adventure.Employee
   SET organizationnode = organizationnode || ((SUBSTRING(org, 5,3)||SUBSTRING(org, 9,3)||SUBSTRING(org, 13,1)||SUBSTRING(org, 15,3))::bit(10)::INTEGER + 80)::VARCHAR || CASE SUBSTRING(org, 18, 1) WHEN '0' THEN '.' ELSE '/' END,
     org = SUBSTRING(org, 19, 9999)
    WHERE org LIKE '1110%';
  IF FOUND THEN
    got_none := false;
  END IF;
  EXIT WHEN got_none;
  END LOOP;
END
$func$ LANGUAGE plpgsql;

SELECT f_ConvertOrgNodes();
-- Drop the original binary hierarchyid column
ALTER TABLE Adventure.Employee DROP COLUMN Org;
DROP FUNCTION f_ConvertOrgNodes();


  CREATE TABLE Adventure.BillOfMaterials(
    BillOfMaterialsID SERIAL NOT NULL, -- int
    ProductAssemblyID INT NULL,
    ComponentID INT NOT NULL,
    StartDate TIMESTAMP NOT NULL CONSTRAINT "DF_BillOfMaterials_StartDate" DEFAULT (NOW()),
    EndDate TIMESTAMP NULL,
    UnitMeasureCode char(3) NOT NULL,
    BOMLevel smallint NOT NULL,
    PerAssemblyQty decimal(8, 2) NOT NULL CONSTRAINT "DF_BillOfMaterials_PerAssemblyQty" DEFAULT (1.00),
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_BillOfMaterials_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_BillOfMaterials_EndDate" CHECK ((EndDate > StartDate) OR (EndDate IS NULL)),
    CONSTRAINT "CK_BillOfMaterials_ProductAssemblyID" CHECK (ProductAssemblyID <> ComponentID),
    CONSTRAINT "CK_BillOfMaterials_BOMLevel" CHECK (((ProductAssemblyID IS NULL)
        AND (BOMLevel = 0) AND (PerAssemblyQty = 1.00))
        OR ((ProductAssemblyID IS NOT NULL) AND (BOMLevel >= 1))),
    CONSTRAINT "CK_BillOfMaterials_PerAssemblyQty" CHECK (PerAssemblyQty >= 1.00)
  );
  CREATE TABLE Adventure.Culture(
    CultureID char(6) NOT NULL,
    Name "Name" NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Culture_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.Document(
    Doc varchar NULL,-- hierarchyid, will become DocumentNode
    DocumentLevel INTEGER, -- AS DocumentNode.GetLevel(),
    Title varchar(50) NOT NULL,
    Owner INT NOT NULL,
    FolderFlag "Flag" NOT NULL CONSTRAINT "DF_Document_FolderFlag" DEFAULT (false),
    FileName varchar(400) NOT NULL,
    FileExtension varchar(8) NULL,
    Revision char(5) NOT NULL,
    ChangeNumber INT NOT NULL CONSTRAINT "DF_Document_ChangeNumber" DEFAULT (0),
    Status smallint NOT NULL, -- tinyint
    DocumentSummary text NULL,
    Document bytea  NULL, -- varbinary
    rowguid uuid NOT NULL UNIQUE CONSTRAINT "DF_Document_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Document_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_Document_Status" CHECK (Status BETWEEN 1 AND 3)
  );
  CREATE TABLE Adventure.ProductCategory(
    ProductCategoryID SERIAL NOT NULL, -- int
    Name "Name" NOT NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_ProductCategory_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductCategory_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.ProductSubcategory(
    ProductSubcategoryID SERIAL NOT NULL, -- int
    ProductCategoryID INT NOT NULL,
    Name "Name" NOT NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_ProductSubcategory_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductSubcategory_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.ProductModel(
    ProductModelID SERIAL NOT NULL, -- int
    Name "Name" NOT NULL,
    CatalogDescription XML NULL, -- XML(Adventure.ProductDescriptionSchemaCollection)
    Instructions XML NULL, -- XML(Adventure.ManuInstructionsSchemaCollection)
    rowguid uuid NOT NULL CONSTRAINT "DF_ProductModel_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductModel_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.Product(
    ProductID SERIAL NOT NULL, -- int
    Name "Name" NOT NULL,
    ProductNumber varchar(25) NOT NULL,
    MakeFlag "Flag" NOT NULL CONSTRAINT "DF_Product_MakeFlag" DEFAULT (true),
    FinishedGoodsFlag "Flag" NOT NULL CONSTRAINT "DF_Product_FinishedGoodsFlag" DEFAULT (true),
    Color varchar(15) NULL,
    SafetyStockLevel smallint NOT NULL,
    ReorderPoint smallint NOT NULL,
    StandardCost numeric NOT NULL, -- money
    ListPrice numeric NOT NULL, -- money
    Size varchar(5) NULL,
    SizeUnitMeasureCode char(3) NULL,
    WeightUnitMeasureCode char(3) NULL,
    Weight decimal(8, 2) NULL,
    DaysToManufacture INT NOT NULL,
    ProductLine char(2) NULL,
    Class char(2) NULL,
    Style char(2) NULL,
    ProductSubcategoryID INT NULL,
    ProductModelID INT NULL,
    SellStartDate TIMESTAMP NOT NULL,
    SellEndDate TIMESTAMP NULL,
    DiscontinuedDate TIMESTAMP NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_Product_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Product_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_Product_SafetyStockLevel" CHECK (SafetyStockLevel > 0),
    CONSTRAINT "CK_Product_ReorderPoint" CHECK (ReorderPoint > 0),
    CONSTRAINT "CK_Product_StandardCost" CHECK (StandardCost >= 0.00),
    CONSTRAINT "CK_Product_ListPrice" CHECK (ListPrice >= 0.00),
    CONSTRAINT "CK_Product_Weight" CHECK (Weight > 0.00),
    CONSTRAINT "CK_Product_DaysToManufacture" CHECK (DaysToManufacture >= 0),
    CONSTRAINT "CK_Product_ProductLine" CHECK (UPPER(ProductLine) IN ('S', 'T', 'M', 'R') OR ProductLine IS NULL),
    CONSTRAINT "CK_Product_Class" CHECK (UPPER(Class) IN ('L', 'M', 'H') OR Class IS NULL),
    CONSTRAINT "CK_Product_Style" CHECK (UPPER(Style) IN ('W', 'M', 'U') OR Style IS NULL),
    CONSTRAINT "CK_Product_SellEndDate" CHECK ((SellEndDate >= SellStartDate) OR (SellEndDate IS NULL))
  );
  CREATE TABLE Adventure.ProductCostHistory(
    ProductID INT NOT NULL,
    StartDate TIMESTAMP NOT NULL,
    EndDate TIMESTAMP NULL,
    StandardCost numeric NOT NULL,  -- money
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductCostHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_ProductCostHistory_EndDate" CHECK ((EndDate >= StartDate) OR (EndDate IS NULL)),
    CONSTRAINT "CK_ProductCostHistory_StandardCost" CHECK (StandardCost >= 0.00)
  );
  CREATE TABLE Adventure.ProductDescription(
    ProductDescriptionID SERIAL NOT NULL, -- int
    Description varchar(400) NOT NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_ProductDescription_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductDescription_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.ProductDocument(
    ProductID INT NOT NULL,
    Doc varchar NOT NULL, -- hierarchyid, will become DocumentNode
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductDocument_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.Location(
    LocationID SERIAL NOT NULL, -- smallint
    Name "Name" NOT NULL,
    CostRate numeric NOT NULL CONSTRAINT "DF_Location_CostRate" DEFAULT (0.00), -- smallmoney -- money
    Availability decimal(8, 2) NOT NULL CONSTRAINT "DF_Location_Availability" DEFAULT (0.00),
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Location_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_Location_CostRate" CHECK (CostRate >= 0.00),
    CONSTRAINT "CK_Location_Availability" CHECK (Availability >= 0.00)
  );
  CREATE TABLE Adventure.ProductInventory(
    ProductID INT NOT NULL,
    LocationID smallint NOT NULL,
    Shelf varchar(10) NOT NULL,
    Bin smallint NOT NULL, -- tinyint
    Quantity smallint NOT NULL CONSTRAINT "DF_ProductInventory_Quantity" DEFAULT (0),
    rowguid uuid NOT NULL CONSTRAINT "DF_ProductInventory_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductInventory_ModifiedDate" DEFAULT (NOW()),
--    CONSTRAINT "CK_ProductInventory_Shelf" CHECK ((Shelf LIKE 'AZa-z]') OR (Shelf = 'N/A')),
    CONSTRAINT "CK_ProductInventory_Bin" CHECK (Bin BETWEEN 0 AND 100)
  );
  CREATE TABLE Adventure.ProductListPriceHistory(
    ProductID INT NOT NULL,
    StartDate TIMESTAMP NOT NULL,
    EndDate TIMESTAMP NULL,
    ListPrice numeric NOT NULL,  -- money
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductListPriceHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_ProductListPriceHistory_EndDate" CHECK ((EndDate >= StartDate) OR (EndDate IS NULL)),
    CONSTRAINT "CK_ProductListPriceHistory_ListPrice" CHECK (ListPrice > 0.00)
  );
  CREATE TABLE Adventure.Illustration(
    IllustrationID SERIAL NOT NULL, -- int
    Diagram XML NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Illustration_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.ProductModelIllustration(
    ProductModelID INT NOT NULL,
    IllustrationID INT NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductModelIllustration_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.ProductModelProductDescriptionCulture(
    ProductModelID INT NOT NULL,
    ProductDescriptionID INT NOT NULL,
    CultureID char(6) NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductModelProductDescriptionCulture_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.ProductPhoto(
    ProductPhotoID SERIAL NOT NULL, -- int
    ThumbNailPhoto bytea NULL,-- varbinary
    ThumbnailPhotoFileName varchar(50) NULL,
    LargePhoto bytea NULL,-- varbinary
    LargePhotoFileName varchar(50) NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductPhoto_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.ProductProductPhoto(
    ProductID INT NOT NULL,
    ProductPhotoID INT NOT NULL,
    "primary" "Flag" NOT NULL CONSTRAINT "DF_ProductProductPhoto_Primary" DEFAULT (false),
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductProductPhoto_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.ProductReview(
    ProductReviewID SERIAL NOT NULL, -- int
    ProductID INT NOT NULL,
    ReviewerName "Name" NOT NULL,
    ReviewDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductReview_ReviewDate" DEFAULT (NOW()),
    EmailAddress varchar(50) NOT NULL,
    Rating INT NOT NULL,
    Comments varchar(3850),
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductReview_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_ProductReview_Rating" CHECK (Rating BETWEEN 1 AND 5)
  );
  CREATE TABLE Adventure.ScrapReason(
    ScrapReasonID SERIAL NOT NULL, -- smallint
    Name "Name" NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ScrapReason_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.TransactionHistory(
    TransactionID SERIAL NOT NULL, -- INT IDENTITY (100000, 1)
    ProductID INT NOT NULL,
    ReferenceOrderID INT NOT NULL,
    ReferenceOrderLineID INT NOT NULL CONSTRAINT "DF_TransactionHistory_ReferenceOrderLineID" DEFAULT (0),
    TransactionDate TIMESTAMP NOT NULL CONSTRAINT "DF_TransactionHistory_TransactionDate" DEFAULT (NOW()),
    TransactionType char(1) NOT NULL,
    Quantity INT NOT NULL,
    ActualCost numeric NOT NULL,  -- money
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_TransactionHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_TransactionHistory_TransactionType" CHECK (UPPER(TransactionType) IN ('W', 'S', 'P'))
  );
  CREATE TABLE Adventure.TransactionHistoryArchive(
    TransactionID INT NOT NULL,
    ProductID INT NOT NULL,
    ReferenceOrderID INT NOT NULL,
    ReferenceOrderLineID INT NOT NULL CONSTRAINT "DF_TransactionHistoryArchive_ReferenceOrderLineID" DEFAULT (0),
    TransactionDate TIMESTAMP NOT NULL CONSTRAINT "DF_TransactionHistoryArchive_TransactionDate" DEFAULT (NOW()),
    TransactionType char(1) NOT NULL,
    Quantity INT NOT NULL,
    ActualCost numeric NOT NULL,  -- money
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_TransactionHistoryArchive_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_TransactionHistoryArchive_TransactionType" CHECK (UPPER(TransactionType) IN ('W', 'S', 'P'))
  );
  CREATE TABLE Adventure.UnitMeasure(
    UnitMeasureCode char(3) NOT NULL,
    Name "Name" NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_UnitMeasure_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.WorkOrder(
    WorkOrderID SERIAL NOT NULL, -- int
    ProductID INT NOT NULL,
    OrderQty INT NOT NULL,
    StockedQty INT, -- AS ISNULL(OrderQty - ScrappedQty, 0),
    ScrappedQty smallint NOT NULL,
    StartDate TIMESTAMP NOT NULL,
    EndDate TIMESTAMP NULL,
    DueDate TIMESTAMP NOT NULL,
    ScrapReasonID smallint NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_WorkOrder_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_WorkOrder_OrderQty" CHECK (OrderQty > 0),
    CONSTRAINT "CK_WorkOrder_ScrappedQty" CHECK (ScrappedQty >= 0),
    CONSTRAINT "CK_WorkOrder_EndDate" CHECK ((EndDate >= StartDate) OR (EndDate IS NULL))
  );
  CREATE TABLE Adventure.WorkOrderRouting(
    WorkOrderID INT NOT NULL,
    ProductID INT NOT NULL,
    OperationSequence smallint NOT NULL,
    LocationID smallint NOT NULL,
    ScheduledStartDate TIMESTAMP NOT NULL,
    ScheduledEndDate TIMESTAMP NOT NULL,
    ActualStartDate TIMESTAMP NULL,
    ActualEndDate TIMESTAMP NULL,
    ActualResourceHrs decimal(9, 4) NULL,
    PlannedCost numeric NOT NULL, -- money
    ActualCost numeric NULL,  -- money
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_WorkOrderRouting_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_WorkOrderRouting_ScheduledEndDate" CHECK (ScheduledEndDate >= ScheduledStartDate),
    CONSTRAINT "CK_WorkOrderRouting_ActualEndDate" CHECK ((ActualEndDate >= ActualStartDate)
        OR (ActualEndDate IS NULL) OR (ActualStartDate IS NULL)),
    CONSTRAINT "CK_WorkOrderRouting_ActualResourceHrs" CHECK (ActualResourceHrs >= 0.0000),
    CONSTRAINT "CK_WorkOrderRouting_PlannedCost" CHECK (PlannedCost > 0.00),
    CONSTRAINT "CK_WorkOrderRouting_ActualCost" CHECK (ActualCost > 0.00)
  );

COMMENT ON SCHEMA Production IS 'Contains objects related to products, inventory, and manufacturing.';
-- This doesn't work:
-- SELECT 'Copying data into Adventure.ProductReview';
-- \copy Adventure.ProductReview FROM 'ProductReview.csv' DELIMITER '  ' CSV;

-- so instead ...
ALTER TABLE Adventure.WorkOrder DROP COLUMN StockedQty;
ALTER TABLE Adventure.Document DROP COLUMN DocumentLevel;

-- Document HierarchyID column
ALTER TABLE Adventure.Document ADD DocumentNode VARCHAR DEFAULT '/';
-- Convert from all the hex to a stream of hierarchyid bits
WITH RECURSIVE hier AS (
  SELECT rowguid, doc, get_byte(decode(substring(doc, 1, 2), 'hex'), 0)::bit(8)::varchar AS bits, 2 AS i
    FROM Adventure.Document
  UNION ALL
  SELECT e.rowguid, e.doc, hier.bits || get_byte(decode(substring(e.doc, i + 1, 2), 'hex'), 0)::bit(8)::varchar, i + 2 AS i
    FROM Adventure.Document AS e INNER JOIN
      hier ON e.rowguid = hier.rowguid AND i < LENGTH(e.doc)
)
UPDATE Adventure.Document AS emp
  SET doc = COALESCE(trim(trailing '0' FROM hier.bits::TEXT), '')
  FROM hier
  WHERE emp.rowguid = hier.rowguid
    AND (hier.doc IS NULL OR i = LENGTH(hier.doc));

-- Convert bits to the real hieararchy paths
CREATE OR REPLACE FUNCTION f_ConvertDocNodes()
  RETURNS void AS
$func$
DECLARE
  got_none BOOLEAN;
BEGIN
  LOOP
  got_none := true;
  -- 01 = 0-3
  UPDATE Adventure.Document
   SET DocumentNode = DocumentNode || SUBSTRING(doc, 3,2)::bit(2)::INTEGER::VARCHAR || CASE SUBSTRING(doc, 5, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 6, 9999)
    WHERE doc LIKE '01%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 100 = 4-7
  UPDATE Adventure.Document
   SET DocumentNode = DocumentNode || (SUBSTRING(doc, 4,2)::bit(2)::INTEGER + 4)::VARCHAR || CASE SUBSTRING(doc, 6, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 7, 9999)
    WHERE doc LIKE '100%';
  IF FOUND THEN
    got_none := false;
  END IF;
  
  -- 101 = 8-15
  UPDATE Adventure.Document
   SET DocumentNode = DocumentNode || (SUBSTRING(doc, 4,3)::bit(3)::INTEGER + 8)::VARCHAR || CASE SUBSTRING(doc, 7, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 8, 9999)
    WHERE doc LIKE '101%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 110 = 16-79
  UPDATE Adventure.Document
   SET DocumentNode = DocumentNode || ((SUBSTRING(doc, 4,2)||SUBSTRING(doc, 7,1)||SUBSTRING(doc, 9,3))::bit(6)::INTEGER + 16)::VARCHAR || CASE SUBSTRING(doc, 12, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 13, 9999)
    WHERE doc LIKE '110%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 1110 = 80-1103
  UPDATE Adventure.Document
   SET DocumentNode = DocumentNode || ((SUBSTRING(doc, 5,3)||SUBSTRING(doc, 9,3)||SUBSTRING(doc, 13,1)||SUBSTRING(doc, 15,3))::bit(10)::INTEGER + 80)::VARCHAR || CASE SUBSTRING(doc, 18, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 19, 9999)
    WHERE doc LIKE '1110%';
  IF FOUND THEN
    got_none := false;
  END IF;
  EXIT WHEN got_none;
  END LOOP;
END
$func$ LANGUAGE plpgsql;

SELECT f_ConvertDocNodes();
-- Drop the original binary hierarchyid column
ALTER TABLE Adventure.Document DROP COLUMN Doc;
DROP FUNCTION f_ConvertDocNodes();

-- ProductDocument HierarchyID column
  ALTER TABLE Adventure.ProductDocument ADD DocumentNode VARCHAR DEFAULT '/';
ALTER TABLE Adventure.ProductDocument ADD rowguid uuid NOT NULL CONSTRAINT "DF_ProductDocument_rowguid" DEFAULT (uuid_generate_v1());
-- Convert from all the hex to a stream of hierarchyid bits
WITH RECURSIVE hier AS (
  SELECT rowguid, doc, get_byte(decode(substring(doc, 1, 2), 'hex'), 0)::bit(8)::varchar AS bits, 2 AS i
    FROM Adventure.ProductDocument
  UNION ALL
  SELECT e.rowguid, e.doc, hier.bits || get_byte(decode(substring(e.doc, i + 1, 2), 'hex'), 0)::bit(8)::varchar, i + 2 AS i
    FROM Adventure.ProductDocument AS e INNER JOIN
      hier ON e.rowguid = hier.rowguid AND i < LENGTH(e.doc)
)
UPDATE Adventure.ProductDocument AS emp
  SET doc = COALESCE(trim(trailing '0' FROM hier.bits::TEXT), '')
  FROM hier
  WHERE emp.rowguid = hier.rowguid
    AND (hier.doc IS NULL OR i = LENGTH(hier.doc));

-- Convert bits to the real hieararchy paths
CREATE OR REPLACE FUNCTION f_ConvertDocNodes()
  RETURNS void AS
$func$
DECLARE
  got_none BOOLEAN;
BEGIN
  LOOP
  got_none := true;
  -- 01 = 0-3
  UPDATE Adventure.ProductDocument
   SET DocumentNode = DocumentNode || SUBSTRING(doc, 3,2)::bit(2)::INTEGER::VARCHAR || CASE SUBSTRING(doc, 5, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 6, 9999)
    WHERE doc LIKE '01%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 100 = 4-7
  UPDATE Adventure.ProductDocument
   SET DocumentNode = DocumentNode || (SUBSTRING(doc, 4,2)::bit(2)::INTEGER + 4)::VARCHAR || CASE SUBSTRING(doc, 6, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 7, 9999)
    WHERE doc LIKE '100%';
  IF FOUND THEN
    got_none := false;
  END IF;
  
  -- 101 = 8-15
  UPDATE Adventure.ProductDocument
   SET DocumentNode = DocumentNode || (SUBSTRING(doc, 4,3)::bit(3)::INTEGER + 8)::VARCHAR || CASE SUBSTRING(doc, 7, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 8, 9999)
    WHERE doc LIKE '101%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 110 = 16-79
  UPDATE Adventure.ProductDocument
   SET DocumentNode = DocumentNode || ((SUBSTRING(doc, 4,2)||SUBSTRING(doc, 7,1)||SUBSTRING(doc, 9,3))::bit(6)::INTEGER + 16)::VARCHAR || CASE SUBSTRING(doc, 12, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 13, 9999)
    WHERE doc LIKE '110%';
  IF FOUND THEN
    got_none := false;
  END IF;

  -- 1110 = 80-1103
  UPDATE Adventure.ProductDocument
   SET DocumentNode = DocumentNode || ((SUBSTRING(doc, 5,3)||SUBSTRING(doc, 9,3)||SUBSTRING(doc, 13,1)||SUBSTRING(doc, 15,3))::bit(10)::INTEGER + 80)::VARCHAR || CASE SUBSTRING(doc, 18, 1) WHEN '0' THEN '.' ELSE '/' END,
     doc = SUBSTRING(doc, 19, 9999)
    WHERE doc LIKE '1110%';
  IF FOUND THEN
    got_none := false;
  END IF;
  EXIT WHEN got_none;
  END LOOP;
END
$func$ LANGUAGE plpgsql;

SELECT f_ConvertDocNodes();
-- Drop the original binary hierarchyid column
ALTER TABLE Adventure.ProductDocument DROP COLUMN Doc;
DROP FUNCTION f_ConvertDocNodes();
ALTER TABLE Adventure.ProductDocument DROP COLUMN rowguid;





  CREATE TABLE Adventure.ProductVendor(
    ProductID INT NOT NULL,
    BusinessEntityID INT NOT NULL,
    AverageLeadTime INT NOT NULL,
    StandardPrice numeric NOT NULL, -- money
    LastReceiptCost numeric NULL, -- money
    LastReceiptDate TIMESTAMP NULL,
    MinOrderQty INT NOT NULL,
    MaxOrderQty INT NOT NULL,
    OnOrderQty INT NULL,
    UnitMeasureCode char(3) NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ProductVendor_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_ProductVendor_AverageLeadTime" CHECK (AverageLeadTime >= 1),
    CONSTRAINT "CK_ProductVendor_StandardPrice" CHECK (StandardPrice > 0.00),
    CONSTRAINT "CK_ProductVendor_LastReceiptCost" CHECK (LastReceiptCost > 0.00),
    CONSTRAINT "CK_ProductVendor_MinOrderQty" CHECK (MinOrderQty >= 1),
    CONSTRAINT "CK_ProductVendor_MaxOrderQty" CHECK (MaxOrderQty >= 1),
    CONSTRAINT "CK_ProductVendor_OnOrderQty" CHECK (OnOrderQty >= 0)
  );
  CREATE TABLE Adventure.PurchaseOrderDetail(
    PurchaseOrderID INT NOT NULL,
    PurchaseOrderDetailID SERIAL NOT NULL, -- int
    DueDate TIMESTAMP NOT NULL,
    OrderQty smallint NOT NULL,
    ProductID INT NOT NULL,
    UnitPrice numeric NOT NULL, -- money
    LineTotal numeric, -- AS ISNULL(OrderQty * UnitPrice, 0.00),
    ReceivedQty decimal(8, 2) NOT NULL,
    RejectedQty decimal(8, 2) NOT NULL,
    StockedQty numeric, -- AS ISNULL(ReceivedQty - RejectedQty, 0.00),
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_PurchaseOrderDetail_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_PurchaseOrderDetail_OrderQty" CHECK (OrderQty > 0),
    CONSTRAINT "CK_PurchaseOrderDetail_UnitPrice" CHECK (UnitPrice >= 0.00),
    CONSTRAINT "CK_PurchaseOrderDetail_ReceivedQty" CHECK (ReceivedQty >= 0.00),
    CONSTRAINT "CK_PurchaseOrderDetail_RejectedQty" CHECK (RejectedQty >= 0.00)
  );
  CREATE TABLE Adventure.PurchaseOrderHeader(
    PurchaseOrderID SERIAL NOT NULL,  -- int
    RevisionNumber smallint NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_RevisionNumber" DEFAULT (0),  -- tinyint
    Status smallint NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_Status" DEFAULT (1),  -- tinyint
    EmployeeID INT NOT NULL,
    VendorID INT NOT NULL,
    ShipMethodID INT NOT NULL,
    OrderDate TIMESTAMP NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_OrderDate" DEFAULT (NOW()),
    ShipDate TIMESTAMP NULL,
    SubTotal numeric NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_SubTotal" DEFAULT (0.00),  -- money
    TaxAmt numeric NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_TaxAmt" DEFAULT (0.00),  -- money
    Freight numeric NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_Freight" DEFAULT (0.00),  -- money
    TotalDue numeric, -- AS ISNULL(SubTotal + TaxAmt + Freight, 0) PERSISTED NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_PurchaseOrderHeader_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_PurchaseOrderHeader_Status" CHECK (Status BETWEEN 1 AND 4), -- 1 = Pending; 2 = Approved; 3 = Rejected; 4 = Complete
    CONSTRAINT "CK_PurchaseOrderHeader_ShipDate" CHECK ((ShipDate >= OrderDate) OR (ShipDate IS NULL)),
    CONSTRAINT "CK_PurchaseOrderHeader_SubTotal" CHECK (SubTotal >= 0.00),
    CONSTRAINT "CK_PurchaseOrderHeader_TaxAmt" CHECK (TaxAmt >= 0.00),
    CONSTRAINT "CK_PurchaseOrderHeader_Freight" CHECK (Freight >= 0.00)
  );
  CREATE TABLE Adventure.ShipMethod(
    ShipMethodID SERIAL NOT NULL, -- int
    Name "Name" NOT NULL,
    ShipBase numeric NOT NULL CONSTRAINT "DF_ShipMethod_ShipBase" DEFAULT (0.00), -- money
    ShipRate numeric NOT NULL CONSTRAINT "DF_ShipMethod_ShipRate" DEFAULT (0.00), -- money
    rowguid uuid NOT NULL CONSTRAINT "DF_ShipMethod_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ShipMethod_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_ShipMethod_ShipBase" CHECK (ShipBase > 0.00),
    CONSTRAINT "CK_ShipMethod_ShipRate" CHECK (ShipRate > 0.00)
  );
  CREATE TABLE Adventure.Vendor(
    BusinessEntityID INT NOT NULL,
    AccountNumber "AccountNumber" NOT NULL,
    Name "Name" NOT NULL,
    CreditRating smallint NOT NULL, -- tinyint
    PreferredVendorStatus "Flag" NOT NULL CONSTRAINT "DF_Vendor_PreferredVendorStatus" DEFAULT (true),
    ActiveFlag "Flag" NOT NULL CONSTRAINT "DF_Vendor_ActiveFlag" DEFAULT (true),
    PurchasingWebServiceURL varchar(1024) NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Vendor_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_Vendor_CreditRating" CHECK (CreditRating BETWEEN 1 AND 5)
  );

COMMENT ON SCHEMA Purchasing IS 'Contains objects related to vendors and purchase orders.';
-- Calculated columns that needed to be there just for the CSV import
ALTER TABLE Adventure.PurchaseOrderDetail DROP COLUMN LineTotal;
ALTER TABLE Adventure.PurchaseOrderDetail DROP COLUMN StockedQty;
ALTER TABLE Adventure.PurchaseOrderHeader DROP COLUMN TotalDue;



  CREATE TABLE Adventure.CountryRegionCurrency(
    CountryRegionCode varchar(3) NOT NULL,
    CurrencyCode char(3) NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_CountryRegionCurrency_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.CreditCard(
    CreditCardID SERIAL NOT NULL, -- int
    CardType varchar(50) NOT NULL,
    CardNumber varchar(25) NOT NULL,
    ExpMonth smallint NOT NULL, -- tinyint
    ExpYear smallint NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_CreditCard_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.Currency(
    CurrencyCode char(3) NOT NULL,
    Name "Name" NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Currency_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.CurrencyRate(
    CurrencyRateID SERIAL NOT NULL, -- int
    CurrencyRateDate TIMESTAMP NOT NULL,   
    FromCurrencyCode char(3) NOT NULL,
    ToCurrencyCode char(3) NOT NULL,
    AverageRate numeric NOT NULL, -- money
    EndOfDayRate numeric NOT NULL,  -- money
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_CurrencyRate_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.Customer(
    CustomerID SERIAL NOT NULL, --  NOT FOR REPLICATION -- int
    -- A customer may either be a person, a store, or a person who works for a store
    PersonID INT NULL, -- If this customer represents a person, this is non-null
    StoreID INT NULL,  -- If the customer is a store, or is associated with a store then this is non-null.
    TerritoryID INT NULL,
    AccountNumber VARCHAR, -- AS ISNULL('AW' + dbo.ufnLeadingZeros(CustomerID), ''),
    rowguid uuid NOT NULL CONSTRAINT "DF_Customer_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Customer_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.PersonCreditCard(
    BusinessEntityID INT NOT NULL,
    CreditCardID INT NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_PersonCreditCard_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.SalesOrderDetail(
    SalesOrderID INT NOT NULL,
    SalesOrderDetailID SERIAL NOT NULL, -- int
    CarrierTrackingNumber varchar(25) NULL,
    OrderQty smallint NOT NULL,
    ProductID INT NOT NULL,
    SpecialOfferID INT NOT NULL,
    UnitPrice numeric NOT NULL, -- money
    UnitPriceDiscount numeric NOT NULL CONSTRAINT "DF_SalesOrderDetail_UnitPriceDiscount" DEFAULT (0.0), -- money
    LineTotal numeric, -- AS ISNULL(UnitPrice * (1.0 - UnitPriceDiscount) * OrderQty, 0.0),
    rowguid uuid NOT NULL CONSTRAINT "DF_SalesOrderDetail_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_SalesOrderDetail_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesOrderDetail_OrderQty" CHECK (OrderQty > 0),
    CONSTRAINT "CK_SalesOrderDetail_UnitPrice" CHECK (UnitPrice >= 0.00),
    CONSTRAINT "CK_SalesOrderDetail_UnitPriceDiscount" CHECK (UnitPriceDiscount >= 0.00)
  );
  CREATE TABLE Adventure.SalesOrderHeader(
    SalesOrderID SERIAL NOT NULL, --  NOT FOR REPLICATION -- int
    RevisionNumber smallint NOT NULL CONSTRAINT "DF_SalesOrderHeader_RevisionNumber" DEFAULT (0), -- tinyint
    OrderDate TIMESTAMP NOT NULL CONSTRAINT "DF_SalesOrderHeader_OrderDate" DEFAULT (NOW()),
    DueDate TIMESTAMP NOT NULL,
    ShipDate TIMESTAMP NULL,
    Status smallint NOT NULL CONSTRAINT "DF_SalesOrderHeader_Status" DEFAULT (1), -- tinyint
    OnlineOrderFlag "Flag" NOT NULL CONSTRAINT "DF_SalesOrderHeader_OnlineOrderFlag" DEFAULT (true),
    SalesOrderNumber VARCHAR(23), -- AS ISNULL(N'SO' + CONVERT(nvarchar(23), SalesOrderID), N'*** ERROR ***'),
    PurchaseOrderNumber "OrderNumber" NULL,
    AccountNumber "AccountNumber" NULL,
    CustomerID INT NOT NULL,
    SalesPersonID INT NULL,
    TerritoryID INT NULL,
    BillToAddressID INT NOT NULL,
    ShipToAddressID INT NOT NULL,
    ShipMethodID INT NOT NULL,
    CreditCardID INT NULL,
    CreditCardApprovalCode varchar(15) NULL,   
    CurrencyRateID INT NULL,
    SubTotal numeric NOT NULL CONSTRAINT "DF_SalesOrderHeader_SubTotal" DEFAULT (0.00), -- money
    TaxAmt numeric NOT NULL CONSTRAINT "DF_SalesOrderHeader_TaxAmt" DEFAULT (0.00), -- money
    Freight numeric NOT NULL CONSTRAINT "DF_SalesOrderHeader_Freight" DEFAULT (0.00), -- money
    TotalDue numeric, -- AS ISNULL(SubTotal + TaxAmt + Freight, 0),
    Comment varchar(128) NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_SalesOrderHeader_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_SalesOrderHeader_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesOrderHeader_Status" CHECK (Status BETWEEN 0 AND 8),
    CONSTRAINT "CK_SalesOrderHeader_DueDate" CHECK (DueDate >= OrderDate),
    CONSTRAINT "CK_SalesOrderHeader_ShipDate" CHECK ((ShipDate >= OrderDate) OR (ShipDate IS NULL)),
    CONSTRAINT "CK_SalesOrderHeader_SubTotal" CHECK (SubTotal >= 0.00),
    CONSTRAINT "CK_SalesOrderHeader_TaxAmt" CHECK (TaxAmt >= 0.00),
    CONSTRAINT "CK_SalesOrderHeader_Freight" CHECK (Freight >= 0.00)
  );
  CREATE TABLE Adventure.SalesOrderHeaderSalesReason(
    SalesOrderID INT NOT NULL,
    SalesReasonID INT NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_SalesOrderHeaderSalesReason_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.SalesPerson(
    BusinessEntityID INT NOT NULL,
    TerritoryID INT NULL,
    SalesQuota numeric NULL, -- money
    Bonus numeric NOT NULL CONSTRAINT "DF_SalesPerson_Bonus" DEFAULT (0.00), -- money
    CommissionPct numeric NOT NULL CONSTRAINT "DF_SalesPerson_CommissionPct" DEFAULT (0.00), -- smallmoney -- money
    SalesYTD numeric NOT NULL CONSTRAINT "DF_SalesPerson_SalesYTD" DEFAULT (0.00), -- money
    SalesLastYear numeric NOT NULL CONSTRAINT "DF_SalesPerson_SalesLastYear" DEFAULT (0.00), -- money
    rowguid uuid NOT NULL CONSTRAINT "DF_SalesPerson_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_SalesPerson_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesPerson_SalesQuota" CHECK (SalesQuota > 0.00),
    CONSTRAINT "CK_SalesPerson_Bonus" CHECK (Bonus >= 0.00),
    CONSTRAINT "CK_SalesPerson_CommissionPct" CHECK (CommissionPct >= 0.00),
    CONSTRAINT "CK_SalesPerson_SalesYTD" CHECK (SalesYTD >= 0.00),
    CONSTRAINT "CK_SalesPerson_SalesLastYear" CHECK (SalesLastYear >= 0.00)
  );
  CREATE TABLE Adventure.SalesPersonQuotaHistory(
    BusinessEntityID INT NOT NULL,
    QuotaDate TIMESTAMP NOT NULL,
    SalesQuota numeric NOT NULL, -- money
    rowguid uuid NOT NULL CONSTRAINT "DF_SalesPersonQuotaHistory_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_SalesPersonQuotaHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesPersonQuotaHistory_SalesQuota" CHECK (SalesQuota > 0.00)
  );
  CREATE TABLE Adventure.SalesReason(
    SalesReasonID SERIAL NOT NULL, -- int
    Name "Name" NOT NULL,
    ReasonType "Name" NOT NULL,
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_SalesReason_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.SalesTaxRate(
    SalesTaxRateID SERIAL NOT NULL, -- int
    StateProvinceID INT NOT NULL,
    TaxType smallint NOT NULL, -- tinyint
    TaxRate numeric NOT NULL CONSTRAINT "DF_SalesTaxRate_TaxRate" DEFAULT (0.00), -- smallmoney -- money
    Name "Name" NOT NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_SalesTaxRate_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_SalesTaxRate_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesTaxRate_TaxType" CHECK (TaxType BETWEEN 1 AND 3)
  );
  CREATE TABLE Adventure.SalesTerritory(
    TerritoryID SERIAL NOT NULL, -- int
    Name "Name" NOT NULL,
    CountryRegionCode varchar(3) NOT NULL,
    "group" varchar(50) NOT NULL, -- Group
    SalesYTD numeric NOT NULL CONSTRAINT "DF_SalesTerritory_SalesYTD" DEFAULT (0.00), -- money
    SalesLastYear numeric NOT NULL CONSTRAINT "DF_SalesTerritory_SalesLastYear" DEFAULT (0.00), -- money
    CostYTD numeric NOT NULL CONSTRAINT "DF_SalesTerritory_CostYTD" DEFAULT (0.00), -- money
    CostLastYear numeric NOT NULL CONSTRAINT "DF_SalesTerritory_CostLastYear" DEFAULT (0.00), -- money
    rowguid uuid NOT NULL CONSTRAINT "DF_SalesTerritory_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_SalesTerritory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesTerritory_SalesYTD" CHECK (SalesYTD >= 0.00),
    CONSTRAINT "CK_SalesTerritory_SalesLastYear" CHECK (SalesLastYear >= 0.00),
    CONSTRAINT "CK_SalesTerritory_CostYTD" CHECK (CostYTD >= 0.00),
    CONSTRAINT "CK_SalesTerritory_CostLastYear" CHECK (CostLastYear >= 0.00)
  );
  CREATE TABLE Adventure.SalesTerritoryHistory(
    BusinessEntityID INT NOT NULL,  -- A sales person
    TerritoryID INT NOT NULL,
    StartDate TIMESTAMP NOT NULL,
    EndDate TIMESTAMP NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_SalesTerritoryHistory_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_SalesTerritoryHistory_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SalesTerritoryHistory_EndDate" CHECK ((EndDate >= StartDate) OR (EndDate IS NULL))
  );
  CREATE TABLE Adventure.ShoppingCartItem(
    ShoppingCartItemID SERIAL NOT NULL, -- int
    ShoppingCartID varchar(50) NOT NULL,
    Quantity INT NOT NULL CONSTRAINT "DF_ShoppingCartItem_Quantity" DEFAULT (1),
    ProductID INT NOT NULL,
    DateCreated TIMESTAMP NOT NULL CONSTRAINT "DF_ShoppingCartItem_DateCreated" DEFAULT (NOW()),
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_ShoppingCartItem_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_ShoppingCartItem_Quantity" CHECK (Quantity >= 1)
  );
  CREATE TABLE Adventure.SpecialOffer(
    SpecialOfferID SERIAL NOT NULL, -- int
    Description varchar(255) NOT NULL,
    DiscountPct numeric NOT NULL CONSTRAINT "DF_SpecialOffer_DiscountPct" DEFAULT (0.00), -- smallmoney -- money
    Type varchar(50) NOT NULL,
    Category varchar(50) NOT NULL,
    StartDate TIMESTAMP NOT NULL,
    EndDate TIMESTAMP NOT NULL,
    MinQty INT NOT NULL CONSTRAINT "DF_SpecialOffer_MinQty" DEFAULT (0),
    MaxQty INT NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_SpecialOffer_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_SpecialOffer_ModifiedDate" DEFAULT (NOW()),
    CONSTRAINT "CK_SpecialOffer_EndDate" CHECK (EndDate >= StartDate),
    CONSTRAINT "CK_SpecialOffer_DiscountPct" CHECK (DiscountPct >= 0.00),
    CONSTRAINT "CK_SpecialOffer_MinQty" CHECK (MinQty >= 0),
    CONSTRAINT "CK_SpecialOffer_MaxQty"  CHECK (MaxQty >= 0)
  );
  CREATE TABLE Adventure.SpecialOfferProduct(
    SpecialOfferID INT NOT NULL,
    ProductID INT NOT NULL,
    rowguid uuid NOT NULL CONSTRAINT "DF_SpecialOfferProduct_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_SpecialOfferProduct_ModifiedDate" DEFAULT (NOW())
  );
  CREATE TABLE Adventure.Store(
    BusinessEntityID INT NOT NULL,
    Name "Name" NOT NULL,
    SalesPersonID INT NULL,
    Demographics XML NULL, -- XML(Adventure.StoreSurveySchemaCollection)
    rowguid uuid NOT NULL CONSTRAINT "DF_Store_rowguid" DEFAULT (uuid_generate_v1()), -- ROWGUIDCOL
    ModifiedDate TIMESTAMP NOT NULL CONSTRAINT "DF_Store_ModifiedDate" DEFAULT (NOW())
  );

COMMENT ON SCHEMA Sales IS 'Contains objects related to customers, sales orders, and sales territories.';

-- Calculated columns that needed to be there just for the CSV import
ALTER TABLE Adventure.Customer DROP COLUMN AccountNumber;
ALTER TABLE Adventure.SalesOrderDetail DROP COLUMN LineTotal;
ALTER TABLE Adventure.SalesOrderHeader DROP COLUMN SalesOrderNumber;



-------------------------------------
-- TABLE AND COLUMN COMMENTS
-------------------------------------

SET CLIENT_ENCODING=latin1;

-- COMMENT ON TABLE dbo.AWBuildVersion IS 'Current version number of the AdventureWorks2012_CS sample database.';
--   COMMENT ON COLUMN dbo.AWBuildVersion.SystemInformationID IS 'Primary key for AWBuildVersion records.';
--   COMMENT ON COLUMN AWBui.COLU.Version IS 'Version number of the database in 9.yy.mm.dd.00 format.';
--   COMMENT ON COLUMN dbo.AWBuildVersion.VersionDate IS 'Date and time the record was last updated.';

-- COMMENT ON TABLE dbo.DatabaseLog IS 'Audit table tracking all DDL changes made to the AdventureWorks database. Data is captured by the database trigger ddlDatabaseTriggerLog.';
--   COMMENT ON COLUMN dbo.DatabaseLog.PostTime IS 'The date and time the DDL change occurred.';
--   COMMENT ON COLUMN dbo.DatabaseLog.DatabaseUser IS 'The user who implemented the DDL change.';
--   COMMENT ON COLUMN dbo.DatabaseLog.Event IS 'The type of DDL statement that was executed.';
--   COMMENT ON COLUMN dbo.DatabaseLog.Schema IS 'The schema to which the changed object belongs.';
--   COMMENT ON COLUMN dbo.DatabaseLog.Object IS 'The object that was changed by the DDL statment.';
--   COMMENT ON COLUMN dbo.DatabaseLog.TSQL IS 'The exact Transact-SQL statement that was executed.';
--   COMMENT ON COLUMN dbo.DatabaseLog.XmlEvent IS 'The raw XML data generated by database trigger.';

-- COMMENT ON TABLE dbo.ErrorLog IS 'Audit table tracking errors in the the AdventureWorks database that are caught by the CATCH block of a TRY...CATCH construct. Data is inserted by stored procedure dbo.uspLogError when it is executed from inside the CATCH block of a TRY...CATCH construct.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorLogID IS 'Primary key for ErrorLog records.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorTime IS 'The date and time at which the error occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.UserName IS 'The user who executed the batch in which the error occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorNumber IS 'The error number of the error that occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorSeverity IS 'The severity of the error that occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorState IS 'The state number of the error that occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorProcedure IS 'The name of the stored procedure or trigger where the error occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorLine IS 'The line number at which the error occurred.';
--   COMMENT ON COLUMN dbo.ErrorLog.ErrorMessage IS 'The message text of the error that occurred.';

COMMENT ON TABLE Adventure.Address IS 'Street address information for customers, employees, and vendors.';
  COMMENT ON COLUMN Adventure.Address.AddressID IS 'Primary key for Address records.';
  COMMENT ON COLUMN Adventure.Address.AddressLine1 IS 'First street address line.';
  COMMENT ON COLUMN Adventure.Address.AddressLine2 IS 'Second street address line.';
  COMMENT ON COLUMN Adventure.Address.City IS 'Name of the city.';
  COMMENT ON COLUMN Adventure.Address.StateProvinceID IS 'Unique identification number for the state or province. Foreign key to StateProvince table.';
  COMMENT ON COLUMN Adventure.Address.PostalCode IS 'Postal code for the street address.';
  COMMENT ON COLUMN Adventure.Address.SpatialLocation IS 'Latitude and longitude of this address.';

COMMENT ON TABLE Adventure.AddressType IS 'Types of addresses stored in the Address table.';
  COMMENT ON COLUMN Adventure.AddressType.AddressTypeID IS 'Primary key for AddressType records.';
  COMMENT ON COLUMN Adventure.AddressType.Name IS 'Address type description. For example, Billing, Home, or Shipping.';

COMMENT ON TABLE Adventure.BillOfMaterials IS 'Items required to make bicycles and bicycle subassemblies. It identifies the heirarchical relationship between a parent product and its components.';
  COMMENT ON COLUMN Adventure.BillOfMaterials.BillOfMaterialsID IS 'Primary key for BillOfMaterials records.';
  COMMENT ON COLUMN Adventure.BillOfMaterials.ProductAssemblyID IS 'Parent product identification number. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.BillOfMaterials.ComponentID IS 'Component identification number. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.BillOfMaterials.StartDate IS 'Date the component started being used in the assembly item.';
  COMMENT ON COLUMN Adventure.BillOfMaterials.EndDate IS 'Date the component stopped being used in the assembly item.';
  COMMENT ON COLUMN Adventure.BillOfMaterials.UnitMeasureCode IS 'Standard code identifying the unit of measure for the quantity.';
  COMMENT ON COLUMN Adventure.BillOfMaterials.BOMLevel IS 'Indicates the depth the component is from its parent (AssemblyID).';
  COMMENT ON COLUMN Adventure.BillOfMaterials.PerAssemblyQty IS 'Quantity of the component needed to create the assembly.';

COMMENT ON TABLE Adventure.BusinessEntity IS 'Source of the ID that connects vendors, customers, and employees with address and contact information.';
  COMMENT ON COLUMN Adventure.BusinessEntity.BusinessEntityID IS 'Primary key for all customers, vendors, and employees.';

COMMENT ON TABLE Adventure.BusinessEntityAddress IS 'Cross-reference table mapping customers, vendors, and employees to their addresses.';
  COMMENT ON COLUMN Adventure.BusinessEntityAddress.BusinessEntityID IS 'Primary key. Foreign key to BusinessEntity.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.BusinessEntityAddress.AddressID IS 'Primary key. Foreign key to Address.AddressID.';
  COMMENT ON COLUMN Adventure.BusinessEntityAddress.AddressTypeID IS 'Primary key. Foreign key to AddressType.AddressTypeID.';

COMMENT ON TABLE Adventure.BusinessEntityContact IS 'Cross-reference table mapping stores, vendors, and employees to people';
  COMMENT ON COLUMN Adventure.BusinessEntityContact.BusinessEntityID IS 'Primary key. Foreign key to BusinessEntity.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.BusinessEntityContact.PersonID IS 'Primary key. Foreign key to Adventure.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.BusinessEntityContact.ContactTypeID IS 'Primary key.  Foreign key to ContactType.ContactTypeID.';

COMMENT ON TABLE Adventure.ContactType IS 'Lookup table containing the types of business entity contacts.';
  COMMENT ON COLUMN Adventure.ContactType.ContactTypeID IS 'Primary key for ContactType records.';
  COMMENT ON COLUMN Adventure.ContactType.Name IS 'Contact type description.';

COMMENT ON TABLE Adventure.CountryRegionCurrency IS 'Cross-reference table mapping ISO currency codes to a country or region.';
  COMMENT ON COLUMN Adventure.CountryRegionCurrency.CountryRegionCode IS 'ISO code for countries and regions. Foreign key to CountryRegion.CountryRegionCode.';
  COMMENT ON COLUMN Adventure.CountryRegionCurrency.CurrencyCode IS 'ISO standard currency code. Foreign key to Currency.CurrencyCode.';

COMMENT ON TABLE Adventure.CountryRegion IS 'Lookup table containing the ISO standard codes for countries and regions.';
  COMMENT ON COLUMN Adventure.CountryRegion.CountryRegionCode IS 'ISO standard code for countries and regions.';
  COMMENT ON COLUMN Adventure.CountryRegion.Name IS 'Country or region name.';

COMMENT ON TABLE Adventure.CreditCard IS 'Customer credit card information.';
  COMMENT ON COLUMN Adventure.CreditCard.CreditCardID IS 'Primary key for CreditCard records.';
  COMMENT ON COLUMN Adventure.CreditCard.CardType IS 'Credit card name.';
  COMMENT ON COLUMN Adventure.CreditCard.CardNumber IS 'Credit card number.';
  COMMENT ON COLUMN Adventure.CreditCard.ExpMonth IS 'Credit card expiration month.';
  COMMENT ON COLUMN Adventure.CreditCard.ExpYear IS 'Credit card expiration year.';

COMMENT ON TABLE Adventure.Culture IS 'Lookup table containing the languages in which some AdventureWorks data is stored.';
  COMMENT ON COLUMN Adventure.Culture.CultureID IS 'Primary key for Culture records.';
  COMMENT ON COLUMN Adventure.Culture.Name IS 'Culture description.';

COMMENT ON TABLE Adventure.Currency IS 'Lookup table containing standard ISO currencies.';
  COMMENT ON COLUMN Adventure.Currency.CurrencyCode IS 'The ISO code for the Currency.';
  COMMENT ON COLUMN Adventure.Currency.Name IS 'Currency name.';

COMMENT ON TABLE Adventure.CurrencyRate IS 'Currency exchange rates.';
  COMMENT ON COLUMN Adventure.CurrencyRate.CurrencyRateID IS 'Primary key for CurrencyRate records.';
  COMMENT ON COLUMN Adventure.CurrencyRate.CurrencyRateDate IS 'Date and time the exchange rate was obtained.';
  COMMENT ON COLUMN Adventure.CurrencyRate.FromCurrencyCode IS 'Exchange rate was converted from this currency code.';
  COMMENT ON COLUMN Adventure.CurrencyRate.ToCurrencyCode IS 'Exchange rate was converted to this currency code.';
  COMMENT ON COLUMN Adventure.CurrencyRate.AverageRate IS 'Average exchange rate for the day.';
  COMMENT ON COLUMN Adventure.CurrencyRate.EndOfDayRate IS 'Final exchange rate for the day.';

COMMENT ON TABLE Adventure.Customer IS 'Current customer information. Also see the Person and Store tables.';
  COMMENT ON COLUMN Adventure.Customer.CustomerID IS 'Primary key.';
  COMMENT ON COLUMN Adventure.Customer.PersonID IS 'Foreign key to Adventure.BusinessEntityID';
  COMMENT ON COLUMN Adventure.Customer.StoreID IS 'Foreign key to Store.BusinessEntityID';
  COMMENT ON COLUMN Adventure.Customer.TerritoryID IS 'ID of the territory in which the customer is located. Foreign key to SalesTerritory.SalesTerritoryID.';
--  COMMENT ON COLUMN Adventure.Customer.AccountNumber IS 'Unique number identifying the customer assigned by the accounting system.';

COMMENT ON TABLE Adventure.Department IS 'Lookup table containing the departments within the Adventure Works Cycles company.';
  COMMENT ON COLUMN Adventure.Department.DepartmentID IS 'Primary key for Department records.';
  COMMENT ON COLUMN Adventure.Department.Name IS 'Name of the department.';
  COMMENT ON COLUMN Adventure.Department.GroupName IS 'Name of the group to which the department belongs.';

COMMENT ON TABLE Adventure.Document IS 'Product maintenance documents.';
  COMMENT ON COLUMN Adventure.Document.DocumentNode IS 'Primary key for Document records.';
--  COMMENT ON COLUMN Adventure.Document.DocumentLevel IS 'Depth in the document hierarchy.';
  COMMENT ON COLUMN Adventure.Document.Title IS 'Title of the document.';
  COMMENT ON COLUMN Adventure.Document.Owner IS 'Employee who controls the document.  Foreign key to Employee.BusinessEntityID';
  COMMENT ON COLUMN Adventure.Document.FolderFlag IS '0 = This is a folder, 1 = This is a document.';
  COMMENT ON COLUMN Adventure.Document.FileName IS 'File name of the document';
  COMMENT ON COLUMN Adventure.Document.FileExtension IS 'File extension indicating the document type. For example, .doc or .txt.';
  COMMENT ON COLUMN Adventure.Document.Revision IS 'Revision number of the document.';
  COMMENT ON COLUMN Adventure.Document.ChangeNumber IS 'Engineering change approval number.';
  COMMENT ON COLUMN Adventure.Document.Status IS '1 = Pending approval, 2 = Approved, 3 = Obsolete';
  COMMENT ON COLUMN Adventure.Document.DocumentSummary IS 'Document abstract.';
  COMMENT ON COLUMN Adventure.Document.Document IS 'Complete document.';
  COMMENT ON COLUMN Adventure.Document.rowguid IS 'ROWGUIDCOL number uniquely identifying the record. Required for FileStream.';

COMMENT ON TABLE Adventure.EmailAddress IS 'Where to send a person email.';
  COMMENT ON COLUMN Adventure.EmailAddress.BusinessEntityID IS 'Primary key. Person associated with this email address.  Foreign key to Adventure.BusinessEntityID';
  COMMENT ON COLUMN Adventure.EmailAddress.EmailAddressID IS 'Primary key. ID of this email address.';
  COMMENT ON COLUMN Adventure.EmailAddress.EmailAddress IS 'E-mail address for the Adventure.';

COMMENT ON TABLE Adventure.Employee IS 'Employee information such as salary, department, and title.';
  COMMENT ON COLUMN Adventure.Employee.BusinessEntityID IS 'Primary key for Employee records.  Foreign key to BusinessEntity.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.Employee.NationalIDNumber IS 'Unique national identification number such as a social security number.';
  COMMENT ON COLUMN Adventure.Employee.LoginID IS 'Network login.';
  COMMENT ON COLUMN Adventure.Employee.OrganizationNode IS 'Where the employee is located in corporate hierarchy.';
--  COMMENT ON COLUMN Adventure.Employee.OrganizationLevel IS 'The depth of the employee in the corporate hierarchy.';
  COMMENT ON COLUMN Adventure.Employee.JobTitle IS 'Work title such as Buyer or Sales Representative.';
  COMMENT ON COLUMN Adventure.Employee.BirthDate IS 'Date of birth.';
  COMMENT ON COLUMN Adventure.Employee.MaritalStatus IS 'M = Married, S = Single';
  COMMENT ON COLUMN Adventure.Employee.Gender IS 'M = Male, F = Female';
  COMMENT ON COLUMN Adventure.Employee.HireDate IS 'Employee hired on this date.';
  COMMENT ON COLUMN Adventure.Employee.SalariedFlag IS 'Job classification. 0 = Hourly, not exempt from collective bargaining. 1 = Salaried, exempt from collective bargaining.';
  COMMENT ON COLUMN Adventure.Employee.VacationHours IS 'Number of available vacation hours.';
  COMMENT ON COLUMN Adventure.Employee.SickLeaveHours IS 'Number of available sick leave hours.';
  COMMENT ON COLUMN Adventure.Employee.CurrentFlag IS '0 = Inactive, 1 = Active';

COMMENT ON TABLE Adventure.EmployeeDepartmentHistory IS 'Employee department transfers.';
  COMMENT ON COLUMN Adventure.EmployeeDepartmentHistory.BusinessEntityID IS 'Employee identification number. Foreign key to Employee.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.EmployeeDepartmentHistory.DepartmentID IS 'Department in which the employee worked including currently. Foreign key to Department.DepartmentID.';
  COMMENT ON COLUMN Adventure.EmployeeDepartmentHistory.ShiftID IS 'Identifies which 8-hour shift the employee works. Foreign key to Shift.Shift.ID.';
  COMMENT ON COLUMN Adventure.EmployeeDepartmentHistory.StartDate IS 'Date the employee started work in the department.';
  COMMENT ON COLUMN Adventure.EmployeeDepartmentHistory.EndDate IS 'Date the employee left the department. NULL = Current department.';

COMMENT ON TABLE Adventure.EmployeePayHistory IS 'Employee pay history.';
  COMMENT ON COLUMN Adventure.EmployeePayHistory.BusinessEntityID IS 'Employee identification number. Foreign key to Employee.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.EmployeePayHistory.RateChangeDate IS 'Date the change in pay is effective';
  COMMENT ON COLUMN Adventure.EmployeePayHistory.Rate IS 'Salary hourly rate.';
  COMMENT ON COLUMN Adventure.EmployeePayHistory.PayFrequency IS '1 = Salary received monthly, 2 = Salary received biweekly';

COMMENT ON TABLE Adventure.Illustration IS 'Bicycle assembly diagrams.';
  COMMENT ON COLUMN Adventure.Illustration.IllustrationID IS 'Primary key for Illustration records.';
  COMMENT ON COLUMN Adventure.Illustration.Diagram IS 'Illustrations used in manufacturing instructions. Stored as XML.';

COMMENT ON TABLE Adventure.JobCandidate IS 'Résumés submitted to Human Resources by job applicants.';
  COMMENT ON COLUMN Adventure.JobCandidate.JobCandidateID IS 'Primary key for JobCandidate records.';
  COMMENT ON COLUMN Adventure.JobCandidate.BusinessEntityID IS 'Employee identification number if applicant was hired. Foreign key to Employee.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.JobCandidate.Resume IS 'Résumé in XML format.';

COMMENT ON TABLE Adventure.Location IS 'Product inventory and manufacturing locations.';
  COMMENT ON COLUMN Adventure.Location.LocationID IS 'Primary key for Location records.';
  COMMENT ON COLUMN Adventure.Location.Name IS 'Location description.';
  COMMENT ON COLUMN Adventure.Location.CostRate IS 'Standard hourly cost of the manufacturing location.';
  COMMENT ON COLUMN Adventure.Location.Availability IS 'Work capacity (in hours) of the manufacturing location.';

COMMENT ON TABLE Adventure.Password IS 'One way hashed authentication information';
  COMMENT ON COLUMN Adventure.Password.PasswordHash IS 'Password for the e-mail account.';
  COMMENT ON COLUMN Adventure.Password.PasswordSalt IS 'Random value concatenated with the password string before the password is hashed.';

COMMENT ON TABLE Adventure.PersonCreditCard IS 'Cross-reference table mapping people to their credit card information in the CreditCard table.';
  COMMENT ON COLUMN Adventure.PersonCreditCard.BusinessEntityID IS 'Business entity identification number. Foreign key to Adventure.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.PersonCreditCard.CreditCardID IS 'Credit card identification number. Foreign key to CreditCard.CreditCardID.';

COMMENT ON TABLE Adventure.PersonPhone IS 'Telephone number and type of a Adventure.';
  COMMENT ON COLUMN Adventure.PersonPhone.BusinessEntityID IS 'Business entity identification number. Foreign key to Adventure.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.PersonPhone.PhoneNumber IS 'Telephone number identification number.';
  COMMENT ON COLUMN Adventure.PersonPhone.PhoneNumberTypeID IS 'Kind of phone number. Foreign key to PhoneNumberType.PhoneNumberTypeID.';

COMMENT ON TABLE Adventure.PhoneNumberType IS 'Type of phone number of a Adventure.';
  COMMENT ON COLUMN Adventure.PhoneNumberType.PhoneNumberTypeID IS 'Primary key for telephone number type records.';
  COMMENT ON COLUMN Adventure.PhoneNumberType.Name IS 'Name of the telephone number type';

COMMENT ON TABLE Adventure.Product IS 'Products sold or used in the manfacturing of sold products.';
  COMMENT ON COLUMN Adventure.Product.ProductID IS 'Primary key for Product records.';
  COMMENT ON COLUMN Adventure.Product.Name IS 'Name of the product.';
  COMMENT ON COLUMN Adventure.Product.ProductNumber IS 'Unique product identification number.';
  COMMENT ON COLUMN Adventure.Product.MakeFlag IS '0 = Product is purchased, 1 = Product is manufactured in-house.';
  COMMENT ON COLUMN Adventure.Product.FinishedGoodsFlag IS '0 = Product is not a salable item. 1 = Product is salable.';
  COMMENT ON COLUMN Adventure.Product.Color IS 'Product color.';
  COMMENT ON COLUMN Adventure.Product.SafetyStockLevel IS 'Minimum inventory quantity.';
  COMMENT ON COLUMN Adventure.Product.ReorderPoint IS 'Inventory level that triggers a purchase order or work order.';
  COMMENT ON COLUMN Adventure.Product.StandardCost IS 'Standard cost of the product.';
  COMMENT ON COLUMN Adventure.Product.ListPrice IS 'Selling price.';
  COMMENT ON COLUMN Adventure.Product.Size IS 'Product size.';
  COMMENT ON COLUMN Adventure.Product.SizeUnitMeasureCode IS 'Unit of measure for Size column.';
  COMMENT ON COLUMN Adventure.Product.WeightUnitMeasureCode IS 'Unit of measure for Weight column.';
  COMMENT ON COLUMN Adventure.Product.Weight IS 'Product weight.';
  COMMENT ON COLUMN Adventure.Product.DaysToManufacture IS 'Number of days required to manufacture the product.';
  COMMENT ON COLUMN Adventure.Product.ProductLine IS 'R = Road, M = Mountain, T = Touring, S = Standard';
  COMMENT ON COLUMN Adventure.Product.Class IS 'H = High, M = Medium, L = Low';
  COMMENT ON COLUMN Adventure.Product.Style IS 'W = Womens, M = Mens, U = Universal';
  COMMENT ON COLUMN Adventure.Product.ProductSubcategoryID IS 'Product is a member of this product subcategory. Foreign key to ProductSubCategory.ProductSubCategoryID.';
  COMMENT ON COLUMN Adventure.Product.ProductModelID IS 'Product is a member of this product model. Foreign key to ProductModel.ProductModelID.';
  COMMENT ON COLUMN Adventure.Product.SellStartDate IS 'Date the product was available for sale.';
  COMMENT ON COLUMN Adventure.Product.SellEndDate IS 'Date the product was no longer available for sale.';
  COMMENT ON COLUMN Adventure.Product.DiscontinuedDate IS 'Date the product was discontinued.';

COMMENT ON TABLE Adventure.ProductCategory IS 'High-level product categorization.';
  COMMENT ON COLUMN Adventure.ProductCategory.ProductCategoryID IS 'Primary key for ProductCategory records.';
  COMMENT ON COLUMN Adventure.ProductCategory.Name IS 'Category description.';

COMMENT ON TABLE Adventure.ProductCostHistory IS 'Changes in the cost of a product over time.';
  COMMENT ON COLUMN Adventure.ProductCostHistory.ProductID IS 'Product identification number. Foreign key to Product.ProductID';
  COMMENT ON COLUMN Adventure.ProductCostHistory.StartDate IS 'Product cost start date.';
  COMMENT ON COLUMN Adventure.ProductCostHistory.EndDate IS 'Product cost end date.';
  COMMENT ON COLUMN Adventure.ProductCostHistory.StandardCost IS 'Standard cost of the product.';

COMMENT ON TABLE Adventure.ProductDescription IS 'Product descriptions in several languages.';
  COMMENT ON COLUMN Adventure.ProductDescription.ProductDescriptionID IS 'Primary key for ProductDescription records.';
  COMMENT ON COLUMN Adventure.ProductDescription.Description IS 'Description of the product.';

COMMENT ON TABLE Adventure.ProductDocument IS 'Cross-reference table mapping products to related product documents.';
  COMMENT ON COLUMN Adventure.ProductDocument.ProductID IS 'Product identification number. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.ProductDocument.DocumentNode IS 'Document identification number. Foreign key to Document.DocumentNode.';

COMMENT ON TABLE Adventure.ProductInventory IS 'Product inventory information.';
  COMMENT ON COLUMN Adventure.ProductInventory.ProductID IS 'Product identification number. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.ProductInventory.LocationID IS 'Inventory location identification number. Foreign key to Location.LocationID.';
  COMMENT ON COLUMN Adventure.ProductInventory.Shelf IS 'Storage compartment within an inventory location.';
  COMMENT ON COLUMN Adventure.ProductInventory.Bin IS 'Storage container on a shelf in an inventory location.';
  COMMENT ON COLUMN Adventure.ProductInventory.Quantity IS 'Quantity of products in the inventory location.';

COMMENT ON TABLE Adventure.ProductListPriceHistory IS 'Changes in the list price of a product over time.';
  COMMENT ON COLUMN Adventure.ProductListPriceHistory.ProductID IS 'Product identification number. Foreign key to Product.ProductID';
  COMMENT ON COLUMN Adventure.ProductListPriceHistory.StartDate IS 'List price start date.';
  COMMENT ON COLUMN Adventure.ProductListPriceHistory.EndDate IS 'List price end date';
  COMMENT ON COLUMN Adventure.ProductListPriceHistory.ListPrice IS 'Product list price.';

COMMENT ON TABLE Adventure.ProductModel IS 'Product model classification.';
  COMMENT ON COLUMN Adventure.ProductModel.ProductModelID IS 'Primary key for ProductModel records.';
  COMMENT ON COLUMN Adventure.ProductModel.Name IS 'Product model description.';
  COMMENT ON COLUMN Adventure.ProductModel.CatalogDescription IS 'Detailed product catalog information in xml format.';
  COMMENT ON COLUMN Adventure.ProductModel.Instructions IS 'Manufacturing instructions in xml format.';

COMMENT ON TABLE Adventure.ProductModelIllustration IS 'Cross-reference table mapping product models and illustrations.';
  COMMENT ON COLUMN Adventure.ProductModelIllustration.ProductModelID IS 'Primary key. Foreign key to ProductModel.ProductModelID.';
  COMMENT ON COLUMN Adventure.ProductModelIllustration.IllustrationID IS 'Primary key. Foreign key to Illustration.IllustrationID.';

COMMENT ON TABLE Adventure.ProductModelProductDescriptionCulture IS 'Cross-reference table mapping product descriptions and the language the description is written in.';
  COMMENT ON COLUMN Adventure.ProductModelProductDescriptionCulture.ProductModelID IS 'Primary key. Foreign key to ProductModel.ProductModelID.';
  COMMENT ON COLUMN Adventure.ProductModelProductDescriptionCulture.ProductDescriptionID IS 'Primary key. Foreign key to ProductDescription.ProductDescriptionID.';
  COMMENT ON COLUMN Adventure.ProductModelProductDescriptionCulture.CultureID IS 'Culture identification number. Foreign key to Culture.CultureID.';

COMMENT ON TABLE Adventure.ProductPhoto IS 'Product images.';
  COMMENT ON COLUMN Adventure.ProductPhoto.ProductPhotoID IS 'Primary key for ProductPhoto records.';
  COMMENT ON COLUMN Adventure.ProductPhoto.ThumbNailPhoto IS 'Small image of the product.';
  COMMENT ON COLUMN Adventure.ProductPhoto.ThumbnailPhotoFileName IS 'Small image file name.';
  COMMENT ON COLUMN Adventure.ProductPhoto.LargePhoto IS 'Large image of the product.';
  COMMENT ON COLUMN Adventure.ProductPhoto.LargePhotoFileName IS 'Large image file name.';

COMMENT ON TABLE Adventure.ProductProductPhoto IS 'Cross-reference table mapping products and product photos.';
  COMMENT ON COLUMN Adventure.ProductProductPhoto.ProductID IS 'Product identification number. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.ProductProductPhoto.ProductPhotoID IS 'Product photo identification number. Foreign key to ProductPhoto.ProductPhotoID.';
  COMMENT ON COLUMN Adventure.ProductProductPhoto.Primary IS '0 = Photo is not the principal image. 1 = Photo is the principal image.';

COMMENT ON TABLE Adventure.ProductReview IS 'Customer reviews of products they have purchased.';
  COMMENT ON COLUMN Adventure.ProductReview.ProductReviewID IS 'Primary key for ProductReview records.';
  COMMENT ON COLUMN Adventure.ProductReview.ProductID IS 'Product identification number. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.ProductReview.ReviewerName IS 'Name of the reviewer.';
  COMMENT ON COLUMN Adventure.ProductReview.ReviewDate IS 'Date review was submitted.';
  COMMENT ON COLUMN Adventure.ProductReview.EmailAddress IS 'Reviewer''s e-mail address.';
  COMMENT ON COLUMN Adventure.ProductReview.Rating IS 'Product rating given by the reviewer. Scale is 1 to 5 with 5 as the highest rating.';
  COMMENT ON COLUMN Adventure.ProductReview.Comments IS 'Reviewer''s comments';

COMMENT ON TABLE Adventure.ProductSubcategory IS 'Product subcategories. See ProductCategory table.';
  COMMENT ON COLUMN Adventure.ProductSubcategory.ProductSubcategoryID IS 'Primary key for ProductSubcategory records.';
  COMMENT ON COLUMN Adventure.ProductSubcategory.ProductCategoryID IS 'Product category identification number. Foreign key to ProductCategory.ProductCategoryID.';
  COMMENT ON COLUMN Adventure.ProductSubcategory.Name IS 'Subcategory description.';

COMMENT ON TABLE Adventure.ProductVendor IS 'Cross-reference table mapping vendors with the products they supply.';
  COMMENT ON COLUMN Adventure.ProductVendor.ProductID IS 'Primary key. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.ProductVendor.BusinessEntityID IS 'Primary key. Foreign key to Vendor.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.ProductVendor.AverageLeadTime IS 'The average span of time (in days) between placing an order with the vendor and receiving the purchased product.';
  COMMENT ON COLUMN Adventure.ProductVendor.StandardPrice IS 'The vendor''s usual selling price.';
  COMMENT ON COLUMN Adventure.ProductVendor.LastReceiptCost IS 'The selling price when last purchased.';
  COMMENT ON COLUMN Adventure.ProductVendor.LastReceiptDate IS 'Date the product was last received by the vendor.';
  COMMENT ON COLUMN Adventure.ProductVendor.MinOrderQty IS 'The maximum quantity that should be ordered.';
  COMMENT ON COLUMN Adventure.ProductVendor.MaxOrderQty IS 'The minimum quantity that should be ordered.';
  COMMENT ON COLUMN Adventure.ProductVendor.OnOrderQty IS 'The quantity currently on order.';
  COMMENT ON COLUMN Adventure.ProductVendor.UnitMeasureCode IS 'The product''s unit of measure.';

COMMENT ON TABLE Adventure.PurchaseOrderDetail IS 'Individual products associated with a specific purchase order. See PurchaseOrderHeader.';
  COMMENT ON COLUMN Adventure.PurchaseOrderDetail.PurchaseOrderID IS 'Primary key. Foreign key to PurchaseOrderHeader.PurchaseOrderID.';
  COMMENT ON COLUMN Adventure.PurchaseOrderDetail.PurchaseOrderDetailID IS 'Primary key. One line number per purchased product.';
  COMMENT ON COLUMN Adventure.PurchaseOrderDetail.DueDate IS 'Date the product is expected to be received.';
  COMMENT ON COLUMN Adventure.PurchaseOrderDetail.OrderQty IS 'Quantity ordered.';
  COMMENT ON COLUMN Adventure.PurchaseOrderDetail.ProductID IS 'Product identification number. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.PurchaseOrderDetail.UnitPrice IS 'Vendor''s selling price of a single product.';
--  COMMENT ON COLUMN Adventure.PurchaseOrderDetail.LineTotal IS 'Per product subtotal. Computed as OrderQty * UnitPrice.';
  COMMENT ON COLUMN Adventure.PurchaseOrderDetail.ReceivedQty IS 'Quantity actually received from the vendor.';
  COMMENT ON COLUMN Adventure.PurchaseOrderDetail.RejectedQty IS 'Quantity rejected during inspection.';
--  COMMENT ON COLUMN Adventure.PurchaseOrderDetail.StockedQty IS 'Quantity accepted into inventory. Computed as ReceivedQty - RejectedQty.';

COMMENT ON TABLE Adventure.PurchaseOrderHeader IS 'General purchase order information. See PurchaseOrderDetail.';
  COMMENT ON COLUMN Adventure.PurchaseOrderHeader.PurchaseOrderID IS 'Primary key.';
  COMMENT ON COLUMN Adventure.PurchaseOrderHeader.RevisionNumber IS 'Incremental number to track changes to the purchase order over time.';
  COMMENT ON COLUMN Adventure.PurchaseOrderHeader.Status IS 'Order current status. 1 = Pending; 2 = Approved; 3 = Rejected; 4 = Complete';
  COMMENT ON COLUMN Adventure.PurchaseOrderHeader.EmployeeID IS 'Employee who created the purchase order. Foreign key to Employee.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.PurchaseOrderHeader.VendorID IS 'Vendor with whom the purchase order is placed. Foreign key to Vendor.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.PurchaseOrderHeader.ShipMethodID IS 'Shipping method. Foreign key to ShipMethod.ShipMethodID.';
  COMMENT ON COLUMN Adventure.PurchaseOrderHeader.OrderDate IS 'Purchase order creation date.';
  COMMENT ON COLUMN Adventure.PurchaseOrderHeader.ShipDate IS 'Estimated shipment date from the vendor.';
  COMMENT ON COLUMN Adventure.PurchaseOrderHeader.SubTotal IS 'Purchase order subtotal. Computed as SUM(PurchaseOrderDetail.LineTotal)for the appropriate PurchaseOrderID.';
  COMMENT ON COLUMN Adventure.PurchaseOrderHeader.TaxAmt IS 'Tax amount.';
  COMMENT ON COLUMN Adventure.PurchaseOrderHeader.Freight IS 'Shipping cost.';
--  COMMENT ON COLUMN Adventure.PurchaseOrderHeader.TotalDue IS 'Total due to vendor. Computed as Subtotal + TaxAmt + Freight.';

COMMENT ON TABLE Adventure.SalesOrderDetail IS 'Individual products associated with a specific sales order. See SalesOrderHeader.';
  COMMENT ON COLUMN Adventure.SalesOrderDetail.SalesOrderID IS 'Primary key. Foreign key to SalesOrderHeader.SalesOrderID.';
  COMMENT ON COLUMN Adventure.SalesOrderDetail.SalesOrderDetailID IS 'Primary key. One incremental unique number per product sold.';
  COMMENT ON COLUMN Adventure.SalesOrderDetail.CarrierTrackingNumber IS 'Shipment tracking number supplied by the shipper.';
  COMMENT ON COLUMN Adventure.SalesOrderDetail.OrderQty IS 'Quantity ordered per product.';
  COMMENT ON COLUMN Adventure.SalesOrderDetail.ProductID IS 'Product sold to customer. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.SalesOrderDetail.SpecialOfferID IS 'Promotional code. Foreign key to SpecialOffer.SpecialOfferID.';
  COMMENT ON COLUMN Adventure.SalesOrderDetail.UnitPrice IS 'Selling price of a single product.';
  COMMENT ON COLUMN Adventure.SalesOrderDetail.UnitPriceDiscount IS 'Discount amount.';
--  COMMENT ON COLUMN Adventure.SalesOrderDetail.LineTotal IS 'Per product subtotal. Computed as UnitPrice * (1 - UnitPriceDiscount) * OrderQty.';

COMMENT ON TABLE Adventure.SalesOrderHeader IS 'General sales order information.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.SalesOrderID IS 'Primary key.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.RevisionNumber IS 'Incremental number to track changes to the sales order over time.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.OrderDate IS 'Dates the sales order was created.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.DueDate IS 'Date the order is due to the customer.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.ShipDate IS 'Date the order was shipped to the customer.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.Status IS 'Order current status. 1 = In process; 2 = Approved; 3 = Backordered; 4 = Rejected; 5 = Shipped; 6 = Cancelled';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.OnlineOrderFlag IS '0 = Order placed by sales Adventure. 1 = Order placed online by customer.';
--  COMMENT ON COLUMN Adventure.SalesOrderHeader.SalesOrderNumber IS 'Unique sales order identification number.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.PurchaseOrderNumber IS 'Customer purchase order number reference.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.AccountNumber IS 'Financial accounting number reference.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.CustomerID IS 'Customer identification number. Foreign key to Customer.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.SalesPersonID IS 'Sales person who created the sales order. Foreign key to SalesPerson.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.TerritoryID IS 'Territory in which the sale was made. Foreign key to SalesTerritory.SalesTerritoryID.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.BillToAddressID IS 'Customer billing address. Foreign key to Address.AddressID.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.ShipToAddressID IS 'Customer shipping address. Foreign key to Address.AddressID.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.ShipMethodID IS 'Shipping method. Foreign key to ShipMethod.ShipMethodID.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.CreditCardID IS 'Credit card identification number. Foreign key to CreditCard.CreditCardID.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.CreditCardApprovalCode IS 'Approval code provided by the credit card company.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.CurrencyRateID IS 'Currency exchange rate used. Foreign key to CurrencyRate.CurrencyRateID.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.SubTotal IS 'Sales subtotal. Computed as SUM(SalesOrderDetail.LineTotal)for the appropriate SalesOrderID.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.TaxAmt IS 'Tax amount.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.Freight IS 'Shipping cost.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.TotalDue IS 'Total due from customer. Computed as Subtotal + TaxAmt + Freight.';
  COMMENT ON COLUMN Adventure.SalesOrderHeader.Comment IS 'Sales representative comments.';

COMMENT ON TABLE Adventure.SalesOrderHeaderSalesReason IS 'Cross-reference table mapping sales orders to sales reason codes.';
  COMMENT ON COLUMN Adventure.SalesOrderHeaderSalesReason.SalesOrderID IS 'Primary key. Foreign key to SalesOrderHeader.SalesOrderID.';
  COMMENT ON COLUMN Adventure.SalesOrderHeaderSalesReason.SalesReasonID IS 'Primary key. Foreign key to SalesReason.SalesReasonID.';

COMMENT ON TABLE Adventure.SalesPerson IS 'Sales representative current information.';
  COMMENT ON COLUMN Adventure.SalesPerson.BusinessEntityID IS 'Primary key for SalesPerson records. Foreign key to Employee.BusinessEntityID';
  COMMENT ON COLUMN Adventure.SalesPerson.TerritoryID IS 'Territory currently assigned to. Foreign key to SalesTerritory.SalesTerritoryID.';
  COMMENT ON COLUMN Adventure.SalesPerson.SalesQuota IS 'Projected yearly adventure.';
  COMMENT ON COLUMN Adventure.SalesPerson.Bonus IS 'Bonus due if quota is met.';
  COMMENT ON COLUMN Adventure.SalesPerson.CommissionPct IS 'Commision percent received per sale.';
  COMMENT ON COLUMN Adventure.SalesPerson.SalesYTD IS 'Sales total year to date.';
  COMMENT ON COLUMN Adventure.SalesPerson.SalesLastYear IS 'Sales total of previous year.';

COMMENT ON TABLE Adventure.SalesPersonQuotaHistory IS 'Sales performance tracking.';
  COMMENT ON COLUMN Adventure.SalesPersonQuotaHistory.BusinessEntityID IS 'Sales person identification number. Foreign key to SalesPerson.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.SalesPersonQuotaHistory.QuotaDate IS 'Sales quota date.';
  COMMENT ON COLUMN Adventure.SalesPersonQuotaHistory.SalesQuota IS 'Sales quota amount.';

COMMENT ON TABLE Adventure.SalesReason IS 'Lookup table of customer purchase reasons.';
  COMMENT ON COLUMN Adventure.SalesReason.SalesReasonID IS 'Primary key for SalesReason records.';
  COMMENT ON COLUMN Adventure.SalesReason.Name IS 'Sales reason description.';
  COMMENT ON COLUMN Adventure.SalesReason.ReasonType IS 'Category the sales reason belongs to.';

COMMENT ON TABLE Adventure.SalesTaxRate IS 'Tax rate lookup table.';
  COMMENT ON COLUMN Adventure.SalesTaxRate.SalesTaxRateID IS 'Primary key for SalesTaxRate records.';
  COMMENT ON COLUMN Adventure.SalesTaxRate.StateProvinceID IS 'State, province, or country/region the sales tax applies to.';
  COMMENT ON COLUMN Adventure.SalesTaxRate.TaxType IS '1 = Tax applied to retail transactions, 2 = Tax applied to wholesale transactions, 3 = Tax applied to all sales (retail and wholesale) transactions.';
  COMMENT ON COLUMN Adventure.SalesTaxRate.TaxRate IS 'Tax rate amount.';
  COMMENT ON COLUMN Adventure.SalesTaxRate.Name IS 'Tax rate description.';

COMMENT ON TABLE Adventure.SalesTerritory IS 'Sales territory lookup table.';
  COMMENT ON COLUMN Adventure.SalesTerritory.TerritoryID IS 'Primary key for SalesTerritory records.';
  COMMENT ON COLUMN Adventure.SalesTerritory.Name IS 'Sales territory description';
  COMMENT ON COLUMN Adventure.SalesTerritory.CountryRegionCode IS 'ISO standard country or region code. Foreign key to CountryRegion.CountryRegionCode.';
  COMMENT ON COLUMN Adventure.SalesTerritory.Group IS 'Geographic area to which the sales territory belong.';
  COMMENT ON COLUMN Adventure.SalesTerritory.SalesYTD IS 'Sales in the territory year to date.';
  COMMENT ON COLUMN Adventure.SalesTerritory.SalesLastYear IS 'Sales in the territory the previous year.';
  COMMENT ON COLUMN Adventure.SalesTerritory.CostYTD IS 'Business costs in the territory year to date.';
  COMMENT ON COLUMN Adventure.SalesTerritory.CostLastYear IS 'Business costs in the territory the previous year.';

COMMENT ON TABLE Adventure.SalesTerritoryHistory IS 'Sales representative transfers to other sales territories.';
  COMMENT ON COLUMN Adventure.SalesTerritoryHistory.BusinessEntityID IS 'Primary key. The sales rep.  Foreign key to SalesPerson.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.SalesTerritoryHistory.TerritoryID IS 'Primary key. Territory identification number. Foreign key to SalesTerritory.SalesTerritoryID.';
  COMMENT ON COLUMN Adventure.SalesTerritoryHistory.StartDate IS 'Primary key. Date the sales representive started work in the territory.';
  COMMENT ON COLUMN Adventure.SalesTerritoryHistory.EndDate IS 'Date the sales representative left work in the territory.';

COMMENT ON TABLE Adventure.ScrapReason IS 'Manufacturing failure reasons lookup table.';
  COMMENT ON COLUMN Adventure.ScrapReason.ScrapReasonID IS 'Primary key for ScrapReason records.';
  COMMENT ON COLUMN Adventure.ScrapReason.Name IS 'Failure description.';

COMMENT ON TABLE Adventure.Shift IS 'Work shift lookup table.';
  COMMENT ON COLUMN Adventure.Shift.ShiftID IS 'Primary key for Shift records.';
  COMMENT ON COLUMN Adventure.Shift.Name IS 'Shift description.';
  COMMENT ON COLUMN Adventure.Shift.StartTime IS 'Shift start time.';
  COMMENT ON COLUMN Adventure.Shift.EndTime IS 'Shift end time.';

COMMENT ON TABLE Adventure.ShipMethod IS 'Shipping company lookup table.';
  COMMENT ON COLUMN Adventure.ShipMethod.ShipMethodID IS 'Primary key for ShipMethod records.';
  COMMENT ON COLUMN Adventure.ShipMethod.Name IS 'Shipping company name.';
  COMMENT ON COLUMN Adventure.ShipMethod.ShipBase IS 'Minimum shipping charge.';
  COMMENT ON COLUMN Adventure.ShipMethod.ShipRate IS 'Shipping charge per pound.';

COMMENT ON TABLE Adventure.ShoppingCartItem IS 'Contains online customer orders until the order is submitted or cancelled.';
  COMMENT ON COLUMN Adventure.ShoppingCartItem.ShoppingCartItemID IS 'Primary key for ShoppingCartItem records.';
  COMMENT ON COLUMN Adventure.ShoppingCartItem.ShoppingCartID IS 'Shopping cart identification number.';
  COMMENT ON COLUMN Adventure.ShoppingCartItem.Quantity IS 'Product quantity ordered.';
  COMMENT ON COLUMN Adventure.ShoppingCartItem.ProductID IS 'Product ordered. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.ShoppingCartItem.DateCreated IS 'Date the time the record was created.';

COMMENT ON TABLE Adventure.SpecialOffer IS 'Sale discounts lookup table.';
  COMMENT ON COLUMN Adventure.SpecialOffer.SpecialOfferID IS 'Primary key for SpecialOffer records.';
  COMMENT ON COLUMN Adventure.SpecialOffer.Description IS 'Discount description.';
  COMMENT ON COLUMN Adventure.SpecialOffer.DiscountPct IS 'Discount precentage.';
  COMMENT ON COLUMN Adventure.SpecialOffer.Type IS 'Discount type category.';
  COMMENT ON COLUMN Adventure.SpecialOffer.Category IS 'Group the discount applies to such as Reseller or Customer.';
  COMMENT ON COLUMN Adventure.SpecialOffer.StartDate IS 'Discount start date.';
  COMMENT ON COLUMN Adventure.SpecialOffer.EndDate IS 'Discount end date.';
  COMMENT ON COLUMN Adventure.SpecialOffer.MinQty IS 'Minimum discount percent allowed.';
  COMMENT ON COLUMN Adventure.SpecialOffer.MaxQty IS 'Maximum discount percent allowed.';

COMMENT ON TABLE Adventure.SpecialOfferProduct IS 'Cross-reference table mapping products to special offer discounts.';
  COMMENT ON COLUMN Adventure.SpecialOfferProduct.SpecialOfferID IS 'Primary key for SpecialOfferProduct records.';
  COMMENT ON COLUMN Adventure.SpecialOfferProduct.ProductID IS 'Product identification number. Foreign key to Product.ProductID.';

COMMENT ON TABLE Adventure.StateProvince IS 'State and province lookup table.';
  COMMENT ON COLUMN Adventure.StateProvince.StateProvinceID IS 'Primary key for StateProvince records.';
  COMMENT ON COLUMN Adventure.StateProvince.StateProvinceCode IS 'ISO standard state or province code.';
  COMMENT ON COLUMN Adventure.StateProvince.CountryRegionCode IS 'ISO standard country or region code. Foreign key to CountryRegion.CountryRegionCode.';
  COMMENT ON COLUMN Adventure.StateProvince.IsOnlyStateProvinceFlag IS '0 = StateProvinceCode exists. 1 = StateProvinceCode unavailable, using CountryRegionCode.';
  COMMENT ON COLUMN Adventure.StateProvince.Name IS 'State or province description.';
  COMMENT ON COLUMN Adventure.StateProvince.TerritoryID IS 'ID of the territory in which the state or province is located. Foreign key to SalesTerritory.SalesTerritoryID.';

COMMENT ON TABLE Adventure.Store IS 'Customers (resellers) of Adventure Works products.';
  COMMENT ON COLUMN Adventure.Store.BusinessEntityID IS 'Primary key. Foreign key to Customer.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.Store.Name IS 'Name of the store.';
  COMMENT ON COLUMN Adventure.Store.SalesPersonID IS 'ID of the sales person assigned to the customer. Foreign key to SalesPerson.BusinessEntityID.';
  COMMENT ON COLUMN Adventure.Store.Demographics IS 'Demographic informationg about the store such as the number of employees, annual sales and store type.';


COMMENT ON TABLE Adventure.TransactionHistory IS 'Record of each purchase order, sales order, or work order transaction year to date.';
  COMMENT ON COLUMN Adventure.TransactionHistory.TransactionID IS 'Primary key for TransactionHistory records.';
  COMMENT ON COLUMN Adventure.TransactionHistory.ProductID IS 'Product identification number. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.TransactionHistory.ReferenceOrderID IS 'Purchase order, sales order, or work order identification number.';
  COMMENT ON COLUMN Adventure.TransactionHistory.ReferenceOrderLineID IS 'Line number associated with the purchase order, sales order, or work order.';
  COMMENT ON COLUMN Adventure.TransactionHistory.TransactionDate IS 'Date and time of the transaction.';
  COMMENT ON COLUMN Adventure.TransactionHistory.TransactionType IS 'W = WorkOrder, S = SalesOrder, P = PurchaseOrder';
  COMMENT ON COLUMN Adventure.TransactionHistory.Quantity IS 'Product quantity.';
  COMMENT ON COLUMN Adventure.TransactionHistory.ActualCost IS 'Product cost.';

COMMENT ON TABLE Adventure.TransactionHistoryArchive IS 'Transactions for previous years.';
  COMMENT ON COLUMN Adventure.TransactionHistoryArchive.TransactionID IS 'Primary key for TransactionHistoryArchive records.';
  COMMENT ON COLUMN Adventure.TransactionHistoryArchive.ProductID IS 'Product identification number. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.TransactionHistoryArchive.ReferenceOrderID IS 'Purchase order, sales order, or work order identification number.';
  COMMENT ON COLUMN Adventure.TransactionHistoryArchive.ReferenceOrderLineID IS 'Line number associated with the purchase order, sales order, or work order.';
  COMMENT ON COLUMN Adventure.TransactionHistoryArchive.TransactionDate IS 'Date and time of the transaction.';
  COMMENT ON COLUMN Adventure.TransactionHistoryArchive.TransactionType IS 'W = Work Order, S = Sales Order, P = Purchase Order';
  COMMENT ON COLUMN Adventure.TransactionHistoryArchive.Quantity IS 'Product quantity.';
  COMMENT ON COLUMN Adventure.TransactionHistoryArchive.ActualCost IS 'Product cost.';

COMMENT ON TABLE Adventure.UnitMeasure IS 'Unit of measure lookup table.';
  COMMENT ON COLUMN Adventure.UnitMeasure.UnitMeasureCode IS 'Primary key.';
  COMMENT ON COLUMN Adventure.UnitMeasure.Name IS 'Unit of measure description.';

COMMENT ON TABLE Adventure.Vendor IS 'Companies from whom Adventure Works Cycles purchases parts or other goods.';
  COMMENT ON COLUMN Adventure.Vendor.BusinessEntityID IS 'Primary key for Vendor records.  Foreign key to BusinessEntity.BusinessEntityID';
  COMMENT ON COLUMN Adventure.Vendor.AccountNumber IS 'Vendor account (identification) number.';
  COMMENT ON COLUMN Adventure.Vendor.Name IS 'Company name.';
  COMMENT ON COLUMN Adventure.Vendor.CreditRating IS '1 = Superior, 2 = Excellent, 3 = Above average, 4 = Average, 5 = Below average';
  COMMENT ON COLUMN Adventure.Vendor.PreferredVendorStatus IS '0 = Do not use if another vendor is available. 1 = Preferred over other vendors supplying the same product.';
  COMMENT ON COLUMN Adventure.Vendor.ActiveFlag IS '0 = Vendor no longer used. 1 = Vendor is actively used.';
  COMMENT ON COLUMN Adventure.Vendor.PurchasingWebServiceURL IS 'Vendor URL.';

COMMENT ON TABLE Adventure.WorkOrder IS 'Manufacturing work orders.';
  COMMENT ON COLUMN Adventure.WorkOrder.WorkOrderID IS 'Primary key for WorkOrder records.';
  COMMENT ON COLUMN Adventure.WorkOrder.ProductID IS 'Product identification number. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.WorkOrder.OrderQty IS 'Product quantity to build.';
--  COMMENT ON COLUMN Adventure.WorkOrder.StockedQty IS 'Quantity built and put in inventory.';
  COMMENT ON COLUMN Adventure.WorkOrder.ScrappedQty IS 'Quantity that failed inspection.';
  COMMENT ON COLUMN Adventure.WorkOrder.StartDate IS 'Work order start date.';
  COMMENT ON COLUMN Adventure.WorkOrder.EndDate IS 'Work order end date.';
  COMMENT ON COLUMN Adventure.WorkOrder.DueDate IS 'Work order due date.';
  COMMENT ON COLUMN Adventure.WorkOrder.ScrapReasonID IS 'Reason for inspection failure.';

COMMENT ON TABLE Adventure.WorkOrderRouting IS 'Work order details.';
  COMMENT ON COLUMN Adventure.WorkOrderRouting.WorkOrderID IS 'Primary key. Foreign key to WorkOrder.WorkOrderID.';
  COMMENT ON COLUMN Adventure.WorkOrderRouting.ProductID IS 'Primary key. Foreign key to Product.ProductID.';
  COMMENT ON COLUMN Adventure.WorkOrderRouting.OperationSequence IS 'Primary key. Indicates the manufacturing process sequence.';
  COMMENT ON COLUMN Adventure.WorkOrderRouting.LocationID IS 'Manufacturing location where the part is processed. Foreign key to Location.LocationID.';
  COMMENT ON COLUMN Adventure.WorkOrderRouting.ScheduledStartDate IS 'Planned manufacturing start date.';
  COMMENT ON COLUMN Adventure.WorkOrderRouting.ScheduledEndDate IS 'Planned manufacturing end date.';
  COMMENT ON COLUMN Adventure.WorkOrderRouting.ActualStartDate IS 'Actual start date.';
  COMMENT ON COLUMN Adventure.WorkOrderRouting.ActualEndDate IS 'Actual end date.';
  COMMENT ON COLUMN Adventure.WorkOrderRouting.ActualResourceHrs IS 'Number of manufacturing hours used.';
  COMMENT ON COLUMN Adventure.WorkOrderRouting.PlannedCost IS 'Estimated manufacturing cost.';
  COMMENT ON COLUMN Adventure.WorkOrderRouting.ActualCost IS 'Actual manufacturing cost.';



-------------------------------------
-- PRIMARY KEYS
-------------------------------------

-- ALTER TABLE dbo.AWBuildVersion ADD
--     CONSTRAINT "PK_AWBuildVersion_SystemInformationID" PRIMARY KEY
--     (SystemInformationID);
-- CLUSTER dbo.AWBuildVersion USING "PK_AWBuildVersion_SystemInformationID";

-- ALTER TABLE dbo.DatabaseLog ADD
--     CONSTRAINT "PK_DatabaseLog_DatabaseLogID" PRIMARY KEY
--     (DatabaseLogID);

ALTER TABLE Adventure.Address ADD
    CONSTRAINT "PK_Address_AddressID" PRIMARY KEY
    (AddressID);
CLUSTER Adventure.Address USING "PK_Address_AddressID";

ALTER TABLE Adventure.AddressType ADD
    CONSTRAINT "PK_AddressType_AddressTypeID" PRIMARY KEY
    (AddressTypeID);
CLUSTER Adventure.AddressType USING "PK_AddressType_AddressTypeID";

ALTER TABLE Adventure.BillOfMaterials ADD
    CONSTRAINT "PK_BillOfMaterials_BillOfMaterialsID" PRIMARY KEY
    (BillOfMaterialsID);

ALTER TABLE Adventure.BusinessEntity ADD
    CONSTRAINT "PK_BusinessEntity_BusinessEntityID" PRIMARY KEY
    (BusinessEntityID);
CLUSTER Adventure.BusinessEntity USING "PK_BusinessEntity_BusinessEntityID";

ALTER TABLE Adventure.BusinessEntityAddress ADD
    CONSTRAINT "PK_BusinessEntityAddress_BusinessEntityID_AddressID_AddressType" PRIMARY KEY
    (BusinessEntityID, AddressID, AddressTypeID);
CLUSTER Adventure.BusinessEntityAddress USING "PK_BusinessEntityAddress_BusinessEntityID_AddressID_AddressType";

ALTER TABLE Adventure.BusinessEntityContact ADD
    CONSTRAINT "PK_BusinessEntityContact_BusinessEntityID_PersonID_ContactTypeI" PRIMARY KEY
    (BusinessEntityID, PersonID, ContactTypeID);
CLUSTER Adventure.BusinessEntityContact USING "PK_BusinessEntityContact_BusinessEntityID_PersonID_ContactTypeI";

ALTER TABLE Adventure.ContactType ADD
    CONSTRAINT "PK_ContactType_ContactTypeID" PRIMARY KEY
    (ContactTypeID);
CLUSTER Adventure.ContactType USING "PK_ContactType_ContactTypeID";

ALTER TABLE Adventure.CountryRegionCurrency ADD
    CONSTRAINT "PK_CountryRegionCurrency_CountryRegionCode_CurrencyCode" PRIMARY KEY
    (CountryRegionCode, CurrencyCode);
CLUSTER Adventure.CountryRegionCurrency USING "PK_CountryRegionCurrency_CountryRegionCode_CurrencyCode";

ALTER TABLE Adventure.CountryRegion ADD
    CONSTRAINT "PK_CountryRegion_CountryRegionCode" PRIMARY KEY
    (CountryRegionCode);
CLUSTER Adventure.CountryRegion USING "PK_CountryRegion_CountryRegionCode";

ALTER TABLE Adventure.CreditCard ADD
    CONSTRAINT "PK_CreditCard_CreditCardID" PRIMARY KEY
    (CreditCardID);
CLUSTER Adventure.CreditCard USING "PK_CreditCard_CreditCardID";

ALTER TABLE Adventure.Currency ADD
    CONSTRAINT "PK_Currency_CurrencyCode" PRIMARY KEY
    (CurrencyCode);
CLUSTER Adventure.Currency USING "PK_Currency_CurrencyCode";

ALTER TABLE Adventure.CurrencyRate ADD
    CONSTRAINT "PK_CurrencyRate_CurrencyRateID" PRIMARY KEY
    (CurrencyRateID);
CLUSTER Adventure.CurrencyRate USING "PK_CurrencyRate_CurrencyRateID";

ALTER TABLE Adventure.Customer ADD
    CONSTRAINT "PK_Customer_CustomerID" PRIMARY KEY
    (CustomerID);
CLUSTER Adventure.Customer USING "PK_Customer_CustomerID";

ALTER TABLE Adventure.Culture ADD
    CONSTRAINT "PK_Culture_CultureID" PRIMARY KEY
    (CultureID);
CLUSTER Adventure.Culture USING "PK_Culture_CultureID";

ALTER TABLE Adventure.Document ADD
    CONSTRAINT "PK_Document_DocumentNode" PRIMARY KEY
    (DocumentNode);
CLUSTER Adventure.Document USING "PK_Document_DocumentNode";

ALTER TABLE Adventure.EmailAddress ADD
    CONSTRAINT "PK_EmailAddress_BusinessEntityID_EmailAddressID" PRIMARY KEY
    (BusinessEntityID, EmailAddressID);
CLUSTER Adventure.EmailAddress USING "PK_EmailAddress_BusinessEntityID_EmailAddressID";

ALTER TABLE Adventure.Department ADD
    CONSTRAINT "PK_Department_DepartmentID" PRIMARY KEY
    (DepartmentID);
CLUSTER Adventure.Department USING "PK_Department_DepartmentID";

ALTER TABLE Adventure.Employee ADD
    CONSTRAINT "PK_Employee_BusinessEntityID" PRIMARY KEY
    (BusinessEntityID);
CLUSTER Adventure.Employee USING "PK_Employee_BusinessEntityID";

ALTER TABLE Adventure.EmployeeDepartmentHistory ADD
    CONSTRAINT "PK_EmployeeDepartmentHistory_BusinessEntityID_StartDate_Departm" PRIMARY KEY
    (BusinessEntityID, StartDate, DepartmentID, ShiftID);
CLUSTER Adventure.EmployeeDepartmentHistory USING "PK_EmployeeDepartmentHistory_BusinessEntityID_StartDate_Departm";

ALTER TABLE Adventure.EmployeePayHistory ADD
    CONSTRAINT "PK_EmployeePayHistory_BusinessEntityID_RateChangeDate" PRIMARY KEY
    (BusinessEntityID, RateChangeDate);
CLUSTER Adventure.EmployeePayHistory USING "PK_EmployeePayHistory_BusinessEntityID_RateChangeDate";

ALTER TABLE Adventure.JobCandidate ADD
    CONSTRAINT "PK_JobCandidate_JobCandidateID" PRIMARY KEY
    (JobCandidateID);
CLUSTER Adventure.JobCandidate USING "PK_JobCandidate_JobCandidateID";

ALTER TABLE Adventure.Illustration ADD
    CONSTRAINT "PK_Illustration_IllustrationID" PRIMARY KEY
    (IllustrationID);
CLUSTER Adventure.Illustration USING "PK_Illustration_IllustrationID";

ALTER TABLE Adventure.Location ADD
    CONSTRAINT "PK_Location_LocationID" PRIMARY KEY
    (LocationID);
CLUSTER Adventure.Location USING "PK_Location_LocationID";

ALTER TABLE Adventure.Password ADD
    CONSTRAINT "PK_Password_BusinessEntityID" PRIMARY KEY
    (BusinessEntityID);
CLUSTER Adventure.Password USING "PK_Password_BusinessEntityID";

ALTER TABLE Adventure.Person ADD
    CONSTRAINT "PK_Person_BusinessEntityID" PRIMARY KEY
    (BusinessEntityID);
CLUSTER Adventure.Person USING "PK_Person_BusinessEntityID";

ALTER TABLE Adventure.PersonPhone ADD
    CONSTRAINT "PK_PersonPhone_BusinessEntityID_PhoneNumber_PhoneNumberTypeID" PRIMARY KEY
    (BusinessEntityID, PhoneNumber, PhoneNumberTypeID);
CLUSTER Adventure.PersonPhone USING "PK_PersonPhone_BusinessEntityID_PhoneNumber_PhoneNumberTypeID";

ALTER TABLE Adventure.PhoneNumberType ADD
    CONSTRAINT "PK_PhoneNumberType_PhoneNumberTypeID" PRIMARY KEY
    (PhoneNumberTypeID);
CLUSTER Adventure.PhoneNumberType USING "PK_PhoneNumberType_PhoneNumberTypeID";

ALTER TABLE Adventure.Product ADD
    CONSTRAINT "PK_Product_ProductID" PRIMARY KEY
    (ProductID);
CLUSTER Adventure.Product USING "PK_Product_ProductID";

ALTER TABLE Adventure.ProductCategory ADD
    CONSTRAINT "PK_ProductCategory_ProductCategoryID" PRIMARY KEY
    (ProductCategoryID);
CLUSTER Adventure.ProductCategory USING "PK_ProductCategory_ProductCategoryID";

ALTER TABLE Adventure.ProductCostHistory ADD
    CONSTRAINT "PK_ProductCostHistory_ProductID_StartDate" PRIMARY KEY
    (ProductID, StartDate);
CLUSTER Adventure.ProductCostHistory USING "PK_ProductCostHistory_ProductID_StartDate";

ALTER TABLE Adventure.ProductDescription ADD
    CONSTRAINT "PK_ProductDescription_ProductDescriptionID" PRIMARY KEY
    (ProductDescriptionID);
CLUSTER Adventure.ProductDescription USING "PK_ProductDescription_ProductDescriptionID";

ALTER TABLE Adventure.ProductDocument ADD
    CONSTRAINT "PK_ProductDocument_ProductID_DocumentNode" PRIMARY KEY
    (ProductID, DocumentNode);
CLUSTER Adventure.ProductDocument USING "PK_ProductDocument_ProductID_DocumentNode";

ALTER TABLE Adventure.ProductInventory ADD
    CONSTRAINT "PK_ProductInventory_ProductID_LocationID" PRIMARY KEY
    (ProductID, LocationID);
CLUSTER Adventure.ProductInventory USING "PK_ProductInventory_ProductID_LocationID";

ALTER TABLE Adventure.ProductListPriceHistory ADD
    CONSTRAINT "PK_ProductListPriceHistory_ProductID_StartDate" PRIMARY KEY
    (ProductID, StartDate);
CLUSTER Adventure.ProductListPriceHistory USING "PK_ProductListPriceHistory_ProductID_StartDate";

ALTER TABLE Adventure.ProductModel ADD
    CONSTRAINT "PK_ProductModel_ProductModelID" PRIMARY KEY
    (ProductModelID);
CLUSTER Adventure.ProductModel USING "PK_ProductModel_ProductModelID";

ALTER TABLE Adventure.ProductModelIllustration ADD
    CONSTRAINT "PK_ProductModelIllustration_ProductModelID_IllustrationID" PRIMARY KEY
    (ProductModelID, IllustrationID);
CLUSTER Adventure.ProductModelIllustration USING "PK_ProductModelIllustration_ProductModelID_IllustrationID";

ALTER TABLE Adventure.ProductModelProductDescriptionCulture ADD
    CONSTRAINT "PK_ProductModelProductDescriptionCulture_ProductModelID_Product" PRIMARY KEY
    (ProductModelID, ProductDescriptionID, CultureID);
CLUSTER Adventure.ProductModelProductDescriptionCulture USING "PK_ProductModelProductDescriptionCulture_ProductModelID_Product";

ALTER TABLE Adventure.ProductPhoto ADD
    CONSTRAINT "PK_ProductPhoto_ProductPhotoID" PRIMARY KEY
    (ProductPhotoID);
CLUSTER Adventure.ProductPhoto USING "PK_ProductPhoto_ProductPhotoID";

ALTER TABLE Adventure.ProductProductPhoto ADD
    CONSTRAINT "PK_ProductProductPhoto_ProductID_ProductPhotoID" PRIMARY KEY
    (ProductID, ProductPhotoID);

ALTER TABLE Adventure.ProductReview ADD
    CONSTRAINT "PK_ProductReview_ProductReviewID" PRIMARY KEY
    (ProductReviewID);
CLUSTER Adventure.ProductReview USING "PK_ProductReview_ProductReviewID";

ALTER TABLE Adventure.ProductSubcategory ADD
    CONSTRAINT "PK_ProductSubcategory_ProductSubcategoryID" PRIMARY KEY
    (ProductSubcategoryID);
CLUSTER Adventure.ProductSubcategory USING "PK_ProductSubcategory_ProductSubcategoryID";

ALTER TABLE Adventure.ProductVendor ADD
    CONSTRAINT "PK_ProductVendor_ProductID_BusinessEntityID" PRIMARY KEY
    (ProductID, BusinessEntityID);
CLUSTER Adventure.ProductVendor USING "PK_ProductVendor_ProductID_BusinessEntityID";

ALTER TABLE Adventure.PurchaseOrderDetail ADD
    CONSTRAINT "PK_PurchaseOrderDetail_PurchaseOrderID_PurchaseOrderDetailID" PRIMARY KEY
    (PurchaseOrderID, PurchaseOrderDetailID);
CLUSTER Adventure.PurchaseOrderDetail USING "PK_PurchaseOrderDetail_PurchaseOrderID_PurchaseOrderDetailID";

ALTER TABLE Adventure.PurchaseOrderHeader ADD
    CONSTRAINT "PK_PurchaseOrderHeader_PurchaseOrderID" PRIMARY KEY
    (PurchaseOrderID);
CLUSTER Adventure.PurchaseOrderHeader USING "PK_PurchaseOrderHeader_PurchaseOrderID";

ALTER TABLE Adventure.PersonCreditCard ADD
    CONSTRAINT "PK_PersonCreditCard_BusinessEntityID_CreditCardID" PRIMARY KEY
    (BusinessEntityID, CreditCardID);
CLUSTER Adventure.PersonCreditCard USING "PK_PersonCreditCard_BusinessEntityID_CreditCardID";

ALTER TABLE Adventure.SalesOrderDetail ADD
    CONSTRAINT "PK_SalesOrderDetail_SalesOrderID_SalesOrderDetailID" PRIMARY KEY
    (SalesOrderID, SalesOrderDetailID);
CLUSTER Adventure.SalesOrderDetail USING "PK_SalesOrderDetail_SalesOrderID_SalesOrderDetailID";

ALTER TABLE Adventure.SalesOrderHeader ADD
    CONSTRAINT "PK_SalesOrderHeader_SalesOrderID" PRIMARY KEY
    (SalesOrderID);
CLUSTER Adventure.SalesOrderHeader USING "PK_SalesOrderHeader_SalesOrderID";

ALTER TABLE Adventure.SalesOrderHeaderSalesReason ADD
    CONSTRAINT "PK_SalesOrderHeaderSalesReason_SalesOrderID_SalesReasonID" PRIMARY KEY
    (SalesOrderID, SalesReasonID);
CLUSTER Adventure.SalesOrderHeaderSalesReason USING "PK_SalesOrderHeaderSalesReason_SalesOrderID_SalesReasonID";

ALTER TABLE Adventure.SalesPerson ADD
    CONSTRAINT "PK_SalesPerson_BusinessEntityID" PRIMARY KEY
    (BusinessEntityID);
CLUSTER Adventure.SalesPerson USING "PK_SalesPerson_BusinessEntityID";

ALTER TABLE Adventure.SalesPersonQuotaHistory ADD
    CONSTRAINT "PK_SalesPersonQuotaHistory_BusinessEntityID_QuotaDate" PRIMARY KEY
    (BusinessEntityID, QuotaDate); -- ProductCategoryID);
CLUSTER Adventure.SalesPersonQuotaHistory USING "PK_SalesPersonQuotaHistory_BusinessEntityID_QuotaDate";

ALTER TABLE Adventure.SalesReason ADD
    CONSTRAINT "PK_SalesReason_SalesReasonID" PRIMARY KEY
    (SalesReasonID);
CLUSTER Adventure.SalesReason USING "PK_SalesReason_SalesReasonID";

ALTER TABLE Adventure.SalesTaxRate ADD
    CONSTRAINT "PK_SalesTaxRate_SalesTaxRateID" PRIMARY KEY
    (SalesTaxRateID);
CLUSTER Adventure.SalesTaxRate USING "PK_SalesTaxRate_SalesTaxRateID";

ALTER TABLE Adventure.SalesTerritory ADD
    CONSTRAINT "PK_SalesTerritory_TerritoryID" PRIMARY KEY
    (TerritoryID);
CLUSTER Adventure.SalesTerritory USING "PK_SalesTerritory_TerritoryID";

ALTER TABLE Adventure.SalesTerritoryHistory ADD
    CONSTRAINT "PK_SalesTerritoryHistory_BusinessEntityID_StartDate_TerritoryID" PRIMARY KEY
    (BusinessEntityID,  --Sales person,
     StartDate, TerritoryID);
CLUSTER Adventure.SalesTerritoryHistory USING "PK_SalesTerritoryHistory_BusinessEntityID_StartDate_TerritoryID";

ALTER TABLE Adventure.ScrapReason ADD
    CONSTRAINT "PK_ScrapReason_ScrapReasonID" PRIMARY KEY
    (ScrapReasonID);
CLUSTER Adventure.ScrapReason USING "PK_ScrapReason_ScrapReasonID";

ALTER TABLE Adventure.Shift ADD
    CONSTRAINT "PK_Shift_ShiftID" PRIMARY KEY
    (ShiftID);
CLUSTER Adventure.Shift USING "PK_Shift_ShiftID";

ALTER TABLE Adventure.ShipMethod ADD
    CONSTRAINT "PK_ShipMethod_ShipMethodID" PRIMARY KEY
    (ShipMethodID);
CLUSTER Adventure.ShipMethod USING "PK_ShipMethod_ShipMethodID";

ALTER TABLE Adventure.ShoppingCartItem ADD
    CONSTRAINT "PK_ShoppingCartItem_ShoppingCartItemID" PRIMARY KEY
    (ShoppingCartItemID);
CLUSTER Adventure.ShoppingCartItem USING "PK_ShoppingCartItem_ShoppingCartItemID";

ALTER TABLE Adventure.SpecialOffer ADD
    CONSTRAINT "PK_SpecialOffer_SpecialOfferID" PRIMARY KEY
    (SpecialOfferID);
CLUSTER Adventure.SpecialOffer USING "PK_SpecialOffer_SpecialOfferID";

ALTER TABLE Adventure.SpecialOfferProduct ADD
    CONSTRAINT "PK_SpecialOfferProduct_SpecialOfferID_ProductID" PRIMARY KEY
    (SpecialOfferID, ProductID);
CLUSTER Adventure.SpecialOfferProduct USING "PK_SpecialOfferProduct_SpecialOfferID_ProductID";

ALTER TABLE Adventure.StateProvince ADD
    CONSTRAINT "PK_StateProvince_StateProvinceID" PRIMARY KEY
    (StateProvinceID);
CLUSTER Adventure.StateProvince USING "PK_StateProvince_StateProvinceID";

ALTER TABLE Adventure.Store ADD
    CONSTRAINT "PK_Store_BusinessEntityID" PRIMARY KEY
    (BusinessEntityID);
CLUSTER Adventure.Store USING "PK_Store_BusinessEntityID";

ALTER TABLE Adventure.TransactionHistory ADD
    CONSTRAINT "PK_TransactionHistory_TransactionID" PRIMARY KEY
    (TransactionID);
CLUSTER Adventure.TransactionHistory USING "PK_TransactionHistory_TransactionID";

ALTER TABLE Adventure.TransactionHistoryArchive ADD
    CONSTRAINT "PK_TransactionHistoryArchive_TransactionID" PRIMARY KEY
    (TransactionID);
CLUSTER Adventure.TransactionHistoryArchive USING "PK_TransactionHistoryArchive_TransactionID";

ALTER TABLE Adventure.UnitMeasure ADD
    CONSTRAINT "PK_UnitMeasure_UnitMeasureCode" PRIMARY KEY
    (UnitMeasureCode);
CLUSTER Adventure.UnitMeasure USING "PK_UnitMeasure_UnitMeasureCode";

ALTER TABLE Adventure.Vendor ADD
    CONSTRAINT "PK_Vendor_BusinessEntityID" PRIMARY KEY
    (BusinessEntityID);
CLUSTER Adventure.Vendor USING "PK_Vendor_BusinessEntityID";

ALTER TABLE Adventure.WorkOrder ADD
    CONSTRAINT "PK_WorkOrder_WorkOrderID" PRIMARY KEY
    (WorkOrderID);
CLUSTER Adventure.WorkOrder USING "PK_WorkOrder_WorkOrderID";

ALTER TABLE Adventure.WorkOrderRouting ADD
    CONSTRAINT "PK_WorkOrderRouting_WorkOrderID_ProductID_OperationSequence" PRIMARY KEY
    (WorkOrderID, ProductID, OperationSequence);
CLUSTER Adventure.WorkOrderRouting USING "PK_WorkOrderRouting_WorkOrderID_ProductID_OperationSequence";



-------------------------------------
-- FOREIGN KEYS
-------------------------------------

ALTER TABLE Adventure.Address ADD
    CONSTRAINT "FK_Address_StateProvince_StateProvinceID" FOREIGN KEY
    (StateProvinceID) REFERENCES Adventure.StateProvince(StateProvinceID);

ALTER TABLE Adventure.BillOfMaterials ADD
    CONSTRAINT "FK_BillOfMaterials_Product_ProductAssemblyID" FOREIGN KEY
    (ProductAssemblyID) REFERENCES Adventure.Product(ProductID);
ALTER TABLE Adventure.BillOfMaterials ADD
    CONSTRAINT "FK_BillOfMaterials_Product_ComponentID" FOREIGN KEY
    (ComponentID) REFERENCES Adventure.Product(ProductID);
ALTER TABLE Adventure.BillOfMaterials ADD
    CONSTRAINT "FK_BillOfMaterials_UnitMeasure_UnitMeasureCode" FOREIGN KEY
    (UnitMeasureCode) REFERENCES Adventure.UnitMeasure(UnitMeasureCode);

ALTER TABLE Adventure.BusinessEntityAddress ADD
    CONSTRAINT "FK_BusinessEntityAddress_Address_AddressID" FOREIGN KEY
    (AddressID) REFERENCES Adventure.Address(AddressID);
ALTER TABLE Adventure.BusinessEntityAddress ADD
    CONSTRAINT "FK_BusinessEntityAddress_AddressType_AddressTypeID" FOREIGN KEY
    (AddressTypeID) REFERENCES Adventure.AddressType(AddressTypeID);
ALTER TABLE Adventure.BusinessEntityAddress ADD
    CONSTRAINT "FK_BusinessEntityAddress_BusinessEntity_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.BusinessEntity(BusinessEntityID);

ALTER TABLE Adventure.BusinessEntityContact ADD
    CONSTRAINT "FK_BusinessEntityContact_Person_PersonID" FOREIGN KEY
    (PersonID) REFERENCES Adventure.Person(BusinessEntityID);
ALTER TABLE Adventure.BusinessEntityContact ADD
    CONSTRAINT "FK_BusinessEntityContact_ContactType_ContactTypeID" FOREIGN KEY
    (ContactTypeID) REFERENCES Adventure.ContactType(ContactTypeID);
ALTER TABLE Adventure.BusinessEntityContact ADD
    CONSTRAINT "FK_BusinessEntityContact_BusinessEntity_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.BusinessEntity(BusinessEntityID);

ALTER TABLE Adventure.CountryRegionCurrency ADD
    CONSTRAINT "FK_CountryRegionCurrency_CountryRegion_CountryRegionCode" FOREIGN KEY
    (CountryRegionCode) REFERENCES Adventure.CountryRegion(CountryRegionCode);
ALTER TABLE Adventure.CountryRegionCurrency ADD
    CONSTRAINT "FK_CountryRegionCurrency_Currency_CurrencyCode" FOREIGN KEY
    (CurrencyCode) REFERENCES Adventure.Currency(CurrencyCode);

ALTER TABLE Adventure.CurrencyRate ADD
    CONSTRAINT "FK_CurrencyRate_Currency_FromCurrencyCode" FOREIGN KEY
    (FromCurrencyCode) REFERENCES Adventure.Currency(CurrencyCode);
ALTER TABLE Adventure.CurrencyRate ADD
    CONSTRAINT "FK_CurrencyRate_Currency_ToCurrencyCode" FOREIGN KEY
    (ToCurrencyCode) REFERENCES Adventure.Currency(CurrencyCode);

ALTER TABLE Adventure.Customer ADD
    CONSTRAINT "FK_Customer_Person_PersonID" FOREIGN KEY
    (PersonID) REFERENCES Adventure.Person(BusinessEntityID);
ALTER TABLE Adventure.Customer ADD
    CONSTRAINT "FK_Customer_Store_StoreID" FOREIGN KEY
    (StoreID) REFERENCES Adventure.Store(BusinessEntityID);
ALTER TABLE Adventure.Customer ADD
    CONSTRAINT "FK_Customer_SalesTerritory_TerritoryID" FOREIGN KEY
    (TerritoryID) REFERENCES Adventure.SalesTerritory(TerritoryID);

ALTER TABLE Adventure.Document ADD
    CONSTRAINT "FK_Document_Employee_Owner" FOREIGN KEY
    (Owner) REFERENCES Adventure.Employee(BusinessEntityID);

ALTER TABLE Adventure.EmailAddress ADD
    CONSTRAINT "FK_EmailAddress_Person_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.Person(BusinessEntityID);

ALTER TABLE Adventure.Employee ADD
    CONSTRAINT "FK_Employee_Person_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.Person(BusinessEntityID);

ALTER TABLE Adventure.EmployeeDepartmentHistory ADD
    CONSTRAINT "FK_EmployeeDepartmentHistory_Department_DepartmentID" FOREIGN KEY
    (DepartmentID) REFERENCES Adventure.Department(DepartmentID);
ALTER TABLE Adventure.EmployeeDepartmentHistory ADD
    CONSTRAINT "FK_EmployeeDepartmentHistory_Employee_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.Employee(BusinessEntityID);
ALTER TABLE Adventure.EmployeeDepartmentHistory ADD
    CONSTRAINT "FK_EmployeeDepartmentHistory_Shift_ShiftID" FOREIGN KEY
    (ShiftID) REFERENCES Adventure.Shift(ShiftID);

ALTER TABLE Adventure.EmployeePayHistory ADD
    CONSTRAINT "FK_EmployeePayHistory_Employee_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.Employee(BusinessEntityID);

ALTER TABLE Adventure.JobCandidate ADD
    CONSTRAINT "FK_JobCandidate_Employee_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.Employee(BusinessEntityID);

ALTER TABLE Adventure.Password ADD
    CONSTRAINT "FK_Password_Person_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.Person(BusinessEntityID);

ALTER TABLE Adventure.Person ADD
    CONSTRAINT "FK_Person_BusinessEntity_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.BusinessEntity(BusinessEntityID);

ALTER TABLE Adventure.PersonCreditCard ADD
    CONSTRAINT "FK_PersonCreditCard_Person_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.Person(BusinessEntityID);
ALTER TABLE Adventure.PersonCreditCard ADD
    CONSTRAINT "FK_PersonCreditCard_CreditCard_CreditCardID" FOREIGN KEY
    (CreditCardID) REFERENCES Adventure.CreditCard(CreditCardID);

ALTER TABLE Adventure.PersonPhone ADD
    CONSTRAINT "FK_PersonPhone_Person_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.Person(BusinessEntityID);
ALTER TABLE Adventure.PersonPhone ADD
    CONSTRAINT "FK_PersonPhone_PhoneNumberType_PhoneNumberTypeID" FOREIGN KEY
    (PhoneNumberTypeID) REFERENCES Adventure.PhoneNumberType(PhoneNumberTypeID);

ALTER TABLE Adventure.Product ADD
    CONSTRAINT "FK_Product_UnitMeasure_SizeUnitMeasureCode" FOREIGN KEY
    (SizeUnitMeasureCode) REFERENCES Adventure.UnitMeasure(UnitMeasureCode);
ALTER TABLE Adventure.Product ADD
    CONSTRAINT "FK_Product_UnitMeasure_WeightUnitMeasureCode" FOREIGN KEY
    (WeightUnitMeasureCode) REFERENCES Adventure.UnitMeasure(UnitMeasureCode);
ALTER TABLE Adventure.Product ADD
    CONSTRAINT "FK_Product_ProductModel_ProductModelID" FOREIGN KEY
    (ProductModelID) REFERENCES Adventure.ProductModel(ProductModelID);
ALTER TABLE Adventure.Product ADD
    CONSTRAINT "FK_Product_ProductSubcategory_ProductSubcategoryID" FOREIGN KEY
    (ProductSubcategoryID) REFERENCES Adventure.ProductSubcategory(ProductSubcategoryID);

ALTER TABLE Adventure.ProductCostHistory ADD
    CONSTRAINT "FK_ProductCostHistory_Product_ProductID" FOREIGN KEY
    (ProductID) REFERENCES Adventure.Product(ProductID);

ALTER TABLE Adventure.ProductDocument ADD
    CONSTRAINT "FK_ProductDocument_Product_ProductID" FOREIGN KEY
    (ProductID) REFERENCES Adventure.Product(ProductID);
ALTER TABLE Adventure.ProductDocument ADD
    CONSTRAINT "FK_ProductDocument_Document_DocumentNode" FOREIGN KEY
    (DocumentNode) REFERENCES Adventure.Document(DocumentNode);

ALTER TABLE Adventure.ProductInventory ADD
    CONSTRAINT "FK_ProductInventory_Location_LocationID" FOREIGN KEY
    (LocationID) REFERENCES Adventure.Location(LocationID);
ALTER TABLE Adventure.ProductInventory ADD
    CONSTRAINT "FK_ProductInventory_Product_ProductID" FOREIGN KEY
    (ProductID) REFERENCES Adventure.Product(ProductID);

ALTER TABLE Adventure.ProductListPriceHistory ADD
    CONSTRAINT "FK_ProductListPriceHistory_Product_ProductID" FOREIGN KEY
    (ProductID) REFERENCES Adventure.Product(ProductID);

ALTER TABLE Adventure.ProductModelIllustration ADD
    CONSTRAINT "FK_ProductModelIllustration_ProductModel_ProductModelID" FOREIGN KEY
    (ProductModelID) REFERENCES Adventure.ProductModel(ProductModelID);
ALTER TABLE Adventure.ProductModelIllustration ADD
    CONSTRAINT "FK_ProductModelIllustration_Illustration_IllustrationID" FOREIGN KEY
    (IllustrationID) REFERENCES Adventure.Illustration(IllustrationID);

ALTER TABLE Adventure.ProductModelProductDescriptionCulture ADD
    CONSTRAINT "FK_ProductModelProductDescriptionCulture_ProductDescription_Pro" FOREIGN KEY
    (ProductDescriptionID) REFERENCES Adventure.ProductDescription(ProductDescriptionID);
ALTER TABLE Adventure.ProductModelProductDescriptionCulture ADD
    CONSTRAINT "FK_ProductModelProductDescriptionCulture_Culture_CultureID" FOREIGN KEY
    (CultureID) REFERENCES Adventure.Culture(CultureID);
ALTER TABLE Adventure.ProductModelProductDescriptionCulture ADD
    CONSTRAINT "FK_ProductModelProductDescriptionCulture_ProductModel_ProductMo" FOREIGN KEY
    (ProductModelID) REFERENCES Adventure.ProductModel(ProductModelID);

ALTER TABLE Adventure.ProductProductPhoto ADD
    CONSTRAINT "FK_ProductProductPhoto_Product_ProductID" FOREIGN KEY
    (ProductID) REFERENCES Adventure.Product(ProductID);
ALTER TABLE Adventure.ProductProductPhoto ADD
    CONSTRAINT "FK_ProductProductPhoto_ProductPhoto_ProductPhotoID" FOREIGN KEY
    (ProductPhotoID) REFERENCES Adventure.ProductPhoto(ProductPhotoID);

ALTER TABLE Adventure.ProductSubcategory ADD
    CONSTRAINT "FK_ProductSubcategory_ProductCategory_ProductCategoryID" FOREIGN KEY
    (ProductCategoryID) REFERENCES Adventure.ProductCategory(ProductCategoryID);

ALTER TABLE Adventure.ProductVendor ADD
    CONSTRAINT "FK_ProductVendor_Product_ProductID" FOREIGN KEY
    (ProductID) REFERENCES Adventure.Product(ProductID);
ALTER TABLE Adventure.ProductVendor ADD
    CONSTRAINT "FK_ProductVendor_UnitMeasure_UnitMeasureCode" FOREIGN KEY
    (UnitMeasureCode) REFERENCES Adventure.UnitMeasure(UnitMeasureCode);
ALTER TABLE Adventure.ProductVendor ADD
    CONSTRAINT "FK_ProductVendor_Vendor_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.Vendor(BusinessEntityID);

ALTER TABLE Adventure.PurchaseOrderDetail ADD
    CONSTRAINT "FK_PurchaseOrderDetail_Product_ProductID" FOREIGN KEY
    (ProductID) REFERENCES Adventure.Product(ProductID);
ALTER TABLE Adventure.PurchaseOrderDetail ADD
    CONSTRAINT "FK_PurchaseOrderDetail_PurchaseOrderHeader_PurchaseOrderID" FOREIGN KEY
    (PurchaseOrderID) REFERENCES Adventure.PurchaseOrderHeader(PurchaseOrderID);

ALTER TABLE Adventure.PurchaseOrderHeader ADD
    CONSTRAINT "FK_PurchaseOrderHeader_Employee_EmployeeID" FOREIGN KEY
    (EmployeeID) REFERENCES Adventure.Employee(BusinessEntityID);
ALTER TABLE Adventure.PurchaseOrderHeader ADD
    CONSTRAINT "FK_PurchaseOrderHeader_Vendor_VendorID" FOREIGN KEY
    (VendorID) REFERENCES Adventure.Vendor(BusinessEntityID);
ALTER TABLE Adventure.PurchaseOrderHeader ADD
    CONSTRAINT "FK_PurchaseOrderHeader_ShipMethod_ShipMethodID" FOREIGN KEY
    (ShipMethodID) REFERENCES Adventure.ShipMethod(ShipMethodID);

ALTER TABLE Adventure.SalesOrderDetail ADD
    CONSTRAINT "FK_SalesOrderDetail_SalesOrderHeader_SalesOrderID" FOREIGN KEY
    (SalesOrderID) REFERENCES Adventure.SalesOrderHeader(SalesOrderID) ON DELETE CASCADE;
ALTER TABLE Adventure.SalesOrderDetail ADD
    CONSTRAINT "FK_SalesOrderDetail_SpecialOfferProduct_SpecialOfferIDProductID" FOREIGN KEY
    (SpecialOfferID, ProductID) REFERENCES Adventure.SpecialOfferProduct(SpecialOfferID, ProductID);

ALTER TABLE Adventure.SalesOrderHeader ADD
    CONSTRAINT "FK_SalesOrderHeader_Address_BillToAddressID" FOREIGN KEY
    (BillToAddressID) REFERENCES Adventure.Address(AddressID);
ALTER TABLE Adventure.SalesOrderHeader ADD
    CONSTRAINT "FK_SalesOrderHeader_Address_ShipToAddressID" FOREIGN KEY
    (ShipToAddressID) REFERENCES Adventure.Address(AddressID);
ALTER TABLE Adventure.SalesOrderHeader ADD
    CONSTRAINT "FK_SalesOrderHeader_CreditCard_CreditCardID" FOREIGN KEY
    (CreditCardID) REFERENCES Adventure.CreditCard(CreditCardID);
ALTER TABLE Adventure.SalesOrderHeader ADD
    CONSTRAINT "FK_SalesOrderHeader_CurrencyRate_CurrencyRateID" FOREIGN KEY
    (CurrencyRateID) REFERENCES Adventure.CurrencyRate(CurrencyRateID);
ALTER TABLE Adventure.SalesOrderHeader ADD
    CONSTRAINT "FK_SalesOrderHeader_Customer_CustomerID" FOREIGN KEY
    (CustomerID) REFERENCES Adventure.Customer(CustomerID);
ALTER TABLE Adventure.SalesOrderHeader ADD
    CONSTRAINT "FK_SalesOrderHeader_SalesPerson_SalesPersonID" FOREIGN KEY
    (SalesPersonID) REFERENCES Adventure.SalesPerson(BusinessEntityID);
ALTER TABLE Adventure.SalesOrderHeader ADD
    CONSTRAINT "FK_SalesOrderHeader_ShipMethod_ShipMethodID" FOREIGN KEY
    (ShipMethodID) REFERENCES Adventure.ShipMethod(ShipMethodID);
ALTER TABLE Adventure.SalesOrderHeader ADD
    CONSTRAINT "FK_SalesOrderHeader_SalesTerritory_TerritoryID" FOREIGN KEY
    (TerritoryID) REFERENCES Adventure.SalesTerritory(TerritoryID);

ALTER TABLE Adventure.SalesOrderHeaderSalesReason ADD
    CONSTRAINT "FK_SalesOrderHeaderSalesReason_SalesReason_SalesReasonID" FOREIGN KEY
    (SalesReasonID) REFERENCES Adventure.SalesReason(SalesReasonID);
ALTER TABLE Adventure.SalesOrderHeaderSalesReason ADD
    CONSTRAINT "FK_SalesOrderHeaderSalesReason_SalesOrderHeader_SalesOrderID" FOREIGN KEY
    (SalesOrderID) REFERENCES Adventure.SalesOrderHeader(SalesOrderID) ON DELETE CASCADE;

ALTER TABLE Adventure.SalesPerson ADD
    CONSTRAINT "FK_SalesPerson_Employee_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.Employee(BusinessEntityID);
ALTER TABLE Adventure.SalesPerson ADD
    CONSTRAINT "FK_SalesPerson_SalesTerritory_TerritoryID" FOREIGN KEY
    (TerritoryID) REFERENCES Adventure.SalesTerritory(TerritoryID);

ALTER TABLE Adventure.SalesPersonQuotaHistory ADD
    CONSTRAINT "FK_SalesPersonQuotaHistory_SalesPerson_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.SalesPerson(BusinessEntityID);

ALTER TABLE Adventure.SalesTaxRate ADD
    CONSTRAINT "FK_SalesTaxRate_StateProvince_StateProvinceID" FOREIGN KEY
    (StateProvinceID) REFERENCES Adventure.StateProvince(StateProvinceID);

ALTER TABLE Adventure.SalesTerritory ADD
    CONSTRAINT "FK_SalesTerritory_CountryRegion_CountryRegionCode" FOREIGN KEY
    (CountryRegionCode) REFERENCES Adventure.CountryRegion(CountryRegionCode);

ALTER TABLE Adventure.SalesTerritoryHistory ADD
    CONSTRAINT "FK_SalesTerritoryHistory_SalesPerson_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.SalesPerson(BusinessEntityID);
ALTER TABLE Adventure.SalesTerritoryHistory ADD
    CONSTRAINT "FK_SalesTerritoryHistory_SalesTerritory_TerritoryID" FOREIGN KEY
    (TerritoryID) REFERENCES Adventure.SalesTerritory(TerritoryID);

ALTER TABLE Adventure.ShoppingCartItem ADD
    CONSTRAINT "FK_ShoppingCartItem_Product_ProductID" FOREIGN KEY
    (ProductID) REFERENCES Adventure.Product(ProductID);

ALTER TABLE Adventure.SpecialOfferProduct ADD
    CONSTRAINT "FK_SpecialOfferProduct_Product_ProductID" FOREIGN KEY
    (ProductID) REFERENCES Adventure.Product(ProductID);
ALTER TABLE Adventure.SpecialOfferProduct ADD
    CONSTRAINT "FK_SpecialOfferProduct_SpecialOffer_SpecialOfferID" FOREIGN KEY
    (SpecialOfferID) REFERENCES Adventure.SpecialOffer(SpecialOfferID);

ALTER TABLE Adventure.StateProvince ADD
    CONSTRAINT "FK_StateProvince_CountryRegion_CountryRegionCode" FOREIGN KEY
    (CountryRegionCode) REFERENCES Adventure.CountryRegion(CountryRegionCode);
ALTER TABLE Adventure.StateProvince ADD
    CONSTRAINT "FK_StateProvince_SalesTerritory_TerritoryID" FOREIGN KEY
    (TerritoryID) REFERENCES Adventure.SalesTerritory(TerritoryID);

ALTER TABLE Adventure.Store ADD
    CONSTRAINT "FK_Store_BusinessEntity_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.BusinessEntity(BusinessEntityID);
ALTER TABLE Adventure.Store ADD
    CONSTRAINT "FK_Store_SalesPerson_SalesPersonID" FOREIGN KEY
    (SalesPersonID) REFERENCES Adventure.SalesPerson(BusinessEntityID);

ALTER TABLE Adventure.TransactionHistory ADD
    CONSTRAINT "FK_TransactionHistory_Product_ProductID" FOREIGN KEY
    (ProductID) REFERENCES Adventure.Product(ProductID);

ALTER TABLE Adventure.Vendor ADD
    CONSTRAINT "FK_Vendor_BusinessEntity_BusinessEntityID" FOREIGN KEY
    (BusinessEntityID) REFERENCES Adventure.BusinessEntity(BusinessEntityID);

ALTER TABLE Adventure.WorkOrder ADD
    CONSTRAINT "FK_WorkOrder_Product_ProductID" FOREIGN KEY
    (ProductID) REFERENCES Adventure.Product(ProductID);
ALTER TABLE Adventure.WorkOrder ADD
    CONSTRAINT "FK_WorkOrder_ScrapReason_ScrapReasonID" FOREIGN KEY
    (ScrapReasonID) REFERENCES Adventure.ScrapReason(ScrapReasonID);

ALTER TABLE Adventure.WorkOrderRouting ADD
    CONSTRAINT "FK_WorkOrderRouting_Location_LocationID" FOREIGN KEY
    (LocationID) REFERENCES Adventure.Location(LocationID);
ALTER TABLE Adventure.WorkOrderRouting ADD
    CONSTRAINT "FK_WorkOrderRouting_WorkOrder_WorkOrderID" FOREIGN KEY
    (WorkOrderID) REFERENCES Adventure.WorkOrder(WorkOrderID);



-------------------------------------
-- VIEWS
-------------------------------------

-- Fun to see the difference in XML-oriented queries between MSSQLServer and Postgres.
-- First here's an original MSSQL query:

-- CREATE VIEW [Person].[vAdditionalContactInfo]
-- AS
-- SELECT
--     [BusinessEntityID]
--     ,[FirstName]
--     ,[MiddleName]
--     ,[LastName]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:telephoneNumber)[1]/act:number', 'nvarchar(50)') AS [TelephoneNumber]
--     ,LTRIM(RTRIM([ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:telephoneNumber/act:SpecialInstructions/text())[1]', 'nvarchar(max)'))) AS [TelephoneSpecialInstructions]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:Street)[1]', 'nvarchar(50)') AS [Street]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:City)[1]', 'nvarchar(50)') AS [City]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:StateProvince)[1]', 'nvarchar(50)') AS [StateProvince]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:PostalCode)[1]', 'nvarchar(50)') AS [PostalCode]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:CountryRegion)[1]', 'nvarchar(50)') AS [CountryRegion]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:homePostalAddress/act:SpecialInstructions/text())[1]', 'nvarchar(max)') AS [HomeAddressSpecialInstructions]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:eMail/act:eMailAddress)[1]', 'nvarchar(128)') AS [EMailAddress]
--     ,LTRIM(RTRIM([ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:eMail/act:SpecialInstructions/text())[1]', 'nvarchar(max)'))) AS [EMailSpecialInstructions]
--     ,[ContactInfo].ref.value(N'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--         declare namespace act="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes";
--         (act:eMail/act:SpecialInstructions/act:telephoneNumber/act:number)[1]', 'nvarchar(50)') AS [EMailTelephoneNumber]
--     ,[rowguid]
--     ,[ModifiedDate]
-- FROM [Person].[Person]
-- OUTER APPLY [AdditionalContactInfo].nodes(
--     'declare namespace ci="http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo";
--     /ci:AdditionalContactInfo') AS ContactInfo(ref)
-- WHERE [AdditionalContactInfo] IS NOT NULL;


-- And now the Postgres version, which is a little more trim:

CREATE VIEW Adventure.vAdditionalContactInfo
AS
SELECT
    p.BusinessEntityID
    ,p.FirstName
    ,p.MiddleName
    ,p.LastName
    ,(xpath('(act:telephoneNumber)[1]/act:number/text()',                node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS TelephoneNumber
    ,BTRIM(
     (xpath('(act:telephoneNumber)[1]/act:SpecialInstructions/text()',   node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]::VARCHAR)
               AS TelephoneSpecialInstructions
    ,(xpath('(act:homePostalAddress)[1]/act:Street/text()',              node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS Street
    ,(xpath('(act:homePostalAddress)[1]/act:City/text()',                node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS City
    ,(xpath('(act:homePostalAddress)[1]/act:StateProvince/text()',       node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS StateProvince
    ,(xpath('(act:homePostalAddress)[1]/act:PostalCode/text()',          node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS PostalCode
    ,(xpath('(act:homePostalAddress)[1]/act:CountryRegion/text()',       node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS CountryRegion
    ,(xpath('(act:homePostalAddress)[1]/act:SpecialInstructions/text()', node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS HomeAddressSpecialInstructions
    ,(xpath('(act:eMail)[1]/act:eMailAddress/text()',                    node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS EMailAddress
    ,BTRIM(
     (xpath('(act:eMail)[1]/act:SpecialInstructions/text()',             node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]::VARCHAR)
               AS EMailSpecialInstructions
    ,(xpath('((act:eMail)[1]/act:SpecialInstructions/act:telephoneNumber)[1]/act:number/text()', node, '{{act,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactTypes}}'))[1]
               AS EMailTelephoneNumber
    ,p.rowguid
    ,p.ModifiedDate
FROM Adventure.Person AS p
  LEFT OUTER JOIN
    (SELECT
      BusinessEntityID
      ,UNNEST(xpath('/ci:AdditionalContactInfo',
        additionalcontactinfo,
        '{{ci,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ContactInfo}}')) AS node
    FROM Adventure.Person
    WHERE AdditionalContactInfo IS NOT NULL) AS additional
  ON p.BusinessEntityID = additional.BusinessEntityID;


CREATE VIEW Adventure.vEmployee
AS
SELECT
    e.BusinessEntityID
    ,p.Title
    ,p.FirstName
    ,p.MiddleName
    ,p.LastName
    ,p.Suffix
    ,e.JobTitle 
    ,pp.PhoneNumber
    ,pnt.Name AS PhoneNumberType
    ,ea.EmailAddress
    ,p.EmailPromotion
    ,a.AddressLine1
    ,a.AddressLine2
    ,a.City
    ,sp.Name AS StateProvinceName
    ,a.PostalCode
    ,cr.Name AS CountryRegionName
    ,p.AdditionalContactInfo
FROM Adventure.Employee e
  INNER JOIN Adventure.Person p
    ON p.BusinessEntityID = e.BusinessEntityID
  INNER JOIN Adventure.BusinessEntityAddress bea
    ON bea.BusinessEntityID = e.BusinessEntityID
  INNER JOIN Adventure.Address a
    ON a.AddressID = bea.AddressID
  INNER JOIN Adventure.StateProvince sp
    ON sp.StateProvinceID = a.StateProvinceID
  INNER JOIN Adventure.CountryRegion cr
    ON cr.CountryRegionCode = sp.CountryRegionCode
  LEFT OUTER JOIN Adventure.PersonPhone pp
    ON pp.BusinessEntityID = p.BusinessEntityID
  LEFT OUTER JOIN Adventure.PhoneNumberType pnt
    ON pp.PhoneNumberTypeID = pnt.PhoneNumberTypeID
  LEFT OUTER JOIN Adventure.EmailAddress ea
    ON p.BusinessEntityID = ea.BusinessEntityID;


CREATE VIEW Adventure.vEmployeeDepartment
AS
SELECT
    e.BusinessEntityID
    ,p.Title
    ,p.FirstName
    ,p.MiddleName
    ,p.LastName
    ,p.Suffix
    ,e.JobTitle
    ,d.Name AS Department
    ,d.GroupName
    ,edh.StartDate
FROM Adventure.Employee e
  INNER JOIN Adventure.Person p
    ON p.BusinessEntityID = e.BusinessEntityID
  INNER JOIN Adventure.EmployeeDepartmentHistory edh
    ON e.BusinessEntityID = edh.BusinessEntityID
  INNER JOIN Adventure.Department d
    ON edh.DepartmentID = d.DepartmentID
WHERE edh.EndDate IS NULL;


CREATE VIEW Adventure.vEmployeeDepartmentHistory
AS
SELECT
    e.BusinessEntityID
    ,p.Title
    ,p.FirstName
    ,p.MiddleName
    ,p.LastName
    ,p.Suffix
    ,s.Name AS Shift
    ,d.Name AS Department
    ,d.GroupName
    ,edh.StartDate
    ,edh.EndDate
FROM Adventure.Employee e
  INNER JOIN Adventure.Person p
    ON p.BusinessEntityID = e.BusinessEntityID
  INNER JOIN Adventure.EmployeeDepartmentHistory edh
    ON e.BusinessEntityID = edh.BusinessEntityID
  INNER JOIN Adventure.Department d
    ON edh.DepartmentID = d.DepartmentID
  INNER JOIN Adventure.Shift s
    ON s.ShiftID = edh.ShiftID;


CREATE VIEW Adventure.vIndividualCustomer
AS
SELECT
    p.BusinessEntityID
    ,p.Title
    ,p.FirstName
    ,p.MiddleName
    ,p.LastName
    ,p.Suffix
    ,pp.PhoneNumber
    ,pnt.Name AS PhoneNumberType
    ,ea.EmailAddress
    ,p.EmailPromotion
    ,at.Name AS AddressType
    ,a.AddressLine1
    ,a.AddressLine2
    ,a.City
    ,sp.Name AS StateProvinceName
    ,a.PostalCode
    ,cr.Name AS CountryRegionName
    ,p.Demographics
FROM Adventure.Person p
  INNER JOIN Adventure.BusinessEntityAddress bea
    ON bea.BusinessEntityID = p.BusinessEntityID
  INNER JOIN Adventure.Address a
    ON a.AddressID = bea.AddressID
  INNER JOIN Adventure.StateProvince sp
    ON sp.StateProvinceID = a.StateProvinceID
  INNER JOIN Adventure.CountryRegion cr
    ON cr.CountryRegionCode = sp.CountryRegionCode
  INNER JOIN Adventure.AddressType at
    ON at.AddressTypeID = bea.AddressTypeID
  INNER JOIN Adventure.Customer c
    ON c.PersonID = p.BusinessEntityID
  LEFT OUTER JOIN Adventure.EmailAddress ea
    ON ea.BusinessEntityID = p.BusinessEntityID
  LEFT OUTER JOIN Adventure.PersonPhone pp
    ON pp.BusinessEntityID = p.BusinessEntityID
  LEFT OUTER JOIN Adventure.PhoneNumberType pnt
    ON pnt.PhoneNumberTypeID = pp.PhoneNumberTypeID
WHERE c.StoreID IS NULL;


CREATE VIEW Adventure.vPersonDemographics
AS
SELECT
    BusinessEntityID
    ,CAST((xpath('n:TotalPurchaseYTD/text()', Demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS money)
            AS TotalPurchaseYTD
    ,CAST((xpath('n:DateFirstPurchase/text()', Demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS DATE)
            AS DateFirstPurchase
    ,CAST((xpath('n:BirthDate/text()', Demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS DATE)
            AS BirthDate
    ,(xpath('n:MaritalStatus/text()', Demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(1)
            AS MaritalStatus
    ,(xpath('n:YearlyIncome/text()', Demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(30)
            AS YearlyIncome
    ,(xpath('n:Gender/text()', Demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(1)
            AS Gender
    ,CAST((xpath('n:TotalChildren/text()', Demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS INTEGER)
            AS TotalChildren
    ,CAST((xpath('n:NumberChildrenAtHome/text()', Demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS INTEGER)
            AS NumberChildrenAtHome
    ,(xpath('n:Education/text()', Demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(30)
            AS Education
    ,(xpath('n:Occupation/text()', Demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR(30)
            AS Occupation
    ,CAST((xpath('n:HomeOwnerFlag/text()', Demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS BOOLEAN)
            AS HomeOwnerFlag
    ,CAST((xpath('n:NumberCarsOwned/text()', Demographics, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/IndividualSurvey}}'))[1]::VARCHAR AS INTEGER)
            AS NumberCarsOwned
FROM Adventure.Person
  WHERE Demographics IS NOT NULL;


CREATE VIEW Adventure.vJobCandidate
AS
SELECT
    JobCandidateID
    ,BusinessEntityID
    ,(xpath('/n:Resume/n:Name/n:Name.Prefix/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "Name.Prefix"
    ,(xpath('/n:Resume/n:Name/n:Name.First/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "Name.First"
    ,(xpath('/n:Resume/n:Name/n:Name.Middle/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "Name.Middle"
    ,(xpath('/n:Resume/n:Name/n:Name.Last/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "Name.Last"
    ,(xpath('/n:Resume/n:Name/n:Name.Suffix/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "Name.Suffix"
    ,(xpath('/n:Resume/n:Skills/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar
                   AS "Skills"
    ,(xpath('n:Address/n:Addr.Type/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(30)
                   AS "Addr.Type"
    ,(xpath('n:Address/n:Addr.Location/n:Location/n:Loc.CountryRegion/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(100)
                   AS "Addr.Loc.CountryRegion"
    ,(xpath('n:Address/n:Addr.Location/n:Location/n:Loc.State/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(100)
                   AS "Addr.Loc.State"
    ,(xpath('n:Address/n:Addr.Location/n:Location/n:Loc.City/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(100)
                   AS "Addr.Loc.City"
    ,(xpath('n:Address/n:Addr.PostalCode/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar(20)
                   AS "Addr.PostalCode"
    ,(xpath('/n:Resume/n:EMail/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar
                   AS "EMail"
    ,(xpath('/n:Resume/n:WebSite/text()', Resume, '{{n,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))[1]::varchar
                   AS "WebSite"
    ,ModifiedDate
FROM Adventure.JobCandidate;


-- In this case we UNNEST in order to have multiple previous employments listed for
-- each job candidate.  But things become very brittle when using UNNEST like this,
-- with multiple columns...
-- ... if any of our Employment fragments were missing something, such as randomly a
-- Emp.FunctionCategory is not there, then there will be 0 rows returned.  Each
-- Employment element must contain all 10 sub-elements for this approach to work.
-- (See the Education example below for a better alternate approach!)
CREATE VIEW Adventure.vJobCandidateEmployment
AS
SELECT
    JobCandidateID
    ,CAST(UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.StartDate/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::VARCHAR(20) AS DATE)
                                                AS "Emp.StartDate"
    ,CAST(UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.EndDate/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::VARCHAR(20) AS DATE)
                                                AS "Emp.EndDate"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.OrgName/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar(100)
                                                AS "Emp.OrgName"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.JobTitle/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar(100)
                                                AS "Emp.JobTitle"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.Responsibility/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "Emp.Responsibility"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.FunctionCategory/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "Emp.FunctionCategory"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.IndustryCategory/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "Emp.IndustryCategory"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.Location/ns:Location/ns:Loc.CountryRegion/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "Emp.Loc.CountryRegion"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.Location/ns:Location/ns:Loc.State/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "Emp.Loc.State"
    ,UNNEST(xpath('/ns:Resume/ns:Employment/ns:Emp.Location/ns:Location/ns:Loc.City/text()', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}'))::varchar
                                                AS "Emp.Loc.City"
  FROM Adventure.JobCandidate;


-- In this data set, not every listed education has a minor.  (OK, actually NONE of them do!)
-- So instead of using multiple UNNEST as above, which would result in 0 rows returned,
-- we just UNNEST once in a derived table, then convert each XML fragment into a document again
-- with one <root> element and a shorter namespace for ns:, and finally just use xpath on
-- all the created documents.
CREATE VIEW Adventure.vJobCandidateEducation
AS
SELECT
  jc.JobCandidateID
  ,(xpath('/root/ns:Education/ns:Edu.Level/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(50)
                             AS "Edu.Level"
  ,CAST((xpath('/root/ns:Education/ns:Edu.StartDate/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::VARCHAR(20) AS DATE)
                             AS "Edu.StartDate"
  ,CAST((xpath('/root/ns:Education/ns:Edu.EndDate/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::VARCHAR(20) AS DATE)
                             AS "Edu.EndDate"
  ,(xpath('/root/ns:Education/ns:Edu.Degree/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(50)
                             AS "Edu.Degree"
  ,(xpath('/root/ns:Education/ns:Edu.Major/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(50)
                             AS "Edu.Major"
  ,(xpath('/root/ns:Education/ns:Edu.Minor/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(50)
                             AS "Edu.Minor"
  ,(xpath('/root/ns:Education/ns:Edu.GPA/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(5)
                             AS "Edu.GPA"
  ,(xpath('/root/ns:Education/ns:Edu.GPAScale/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(5)
                             AS "Edu.GPAScale"
  ,(xpath('/root/ns:Education/ns:Edu.School/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(100)
                             AS "Edu.School"
  ,(xpath('/root/ns:Education/ns:Edu.Location/ns:Location/ns:Loc.CountryRegion/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(100)
                             AS "Edu.Loc.CountryRegion"
  ,(xpath('/root/ns:Education/ns:Edu.Location/ns:Location/ns:Loc.State/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(100)
                             AS "Edu.Loc.State"
  ,(xpath('/root/ns:Education/ns:Edu.Location/ns:Location/ns:Loc.City/text()', jc.doc, '{{ns,http://adventureworks.com}}'))[1]::varchar(100)
                             AS "Edu.Loc.City"
FROM (SELECT JobCandidateID
    -- Because the underlying XML data used in this example has namespaces defined at the document level,
    -- when we take individual fragments using UNNEST then each fragment has no idea of the namespaces.
    -- So here each fragment gets turned back into its own document with a root element that defines a
    -- simpler thing for "ns" since this will only be used only in the xpath queries above.
    ,('<root xmlns:ns="http://adventureworks.com">' ||
      unnesting.Education::varchar ||
      '</root>')::xml AS doc
  FROM (SELECT JobCandidateID
      ,UNNEST(xpath('/ns:Resume/ns:Education', Resume, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/Resume}}')) AS Education
    FROM Adventure.JobCandidate) AS unnesting) AS jc;


-- Products and product descriptions by language.
-- We're making this a materialized view so that performance can be better.
CREATE MATERIALIZED VIEW Adventure.vProductAndDescription
AS
SELECT
    p.ProductID
    ,p.Name
    ,pm.Name AS ProductModel
    ,pmx.CultureID
    ,pd.Description
FROM Adventure.Product p
    INNER JOIN Adventure.ProductModel pm
    ON p.ProductModelID = pm.ProductModelID
    INNER JOIN Adventure.ProductModelProductDescriptionCulture pmx
    ON pm.ProductModelID = pmx.ProductModelID
    INNER JOIN Adventure.ProductDescription pd
    ON pmx.ProductDescriptionID = pd.ProductDescriptionID;

-- Index the vProductAndDescription view
CREATE UNIQUE INDEX IX_vProductAndDescription ON Adventure.vProductAndDescription(CultureID, ProductID);
CLUSTER Adventure.vProductAndDescription USING IX_vProductAndDescription;
-- Note that with a materialized view, changes to the underlying tables will
-- not change the contents of the view.  In order to maintain the index, if there
-- are changes to any of the 4 tables then you would need to run:
--   REFRESH MATERIALIZED VIEW Adventure.vProductAndDescription;


CREATE VIEW Adventure.vProductModelCatalogDescription
AS
SELECT
  ProductModelID
  ,Name
  ,(xpath('/p1:ProductDescription/p1:Summary/html:p/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{html,http://www.w3.org/1999/xhtml}}'))[1]::varchar
                                 AS "Summary"
  ,(xpath('/p1:ProductDescription/p1:Manufacturer/p1:Name/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar
                                  AS Manufacturer
  ,(xpath('/p1:ProductDescription/p1:Manufacturer/p1:Copyright/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(30)
                                                  AS Copyright
  ,(xpath('/p1:ProductDescription/p1:Manufacturer/p1:ProductURL/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                  AS ProductURL
  ,(xpath('/p1:ProductDescription/p1:Features/wm:Warranty/wm:WarrantyPeriod/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wm,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain}}' ))[1]::varchar(256)
                                                          AS WarrantyPeriod
  ,(xpath('/p1:ProductDescription/p1:Features/wm:Warranty/wm:Description/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wm,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain}}' ))[1]::varchar(256)
                                                          AS WarrantyDescription
  ,(xpath('/p1:ProductDescription/p1:Features/wm:Maintenance/wm:NoOfYears/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wm,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain}}' ))[1]::varchar(256)
                                                             AS NoOfYears
  ,(xpath('/p1:ProductDescription/p1:Features/wm:Maintenance/wm:Description/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wm,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelWarrAndMain}}' ))[1]::varchar(256)
                                                             AS MaintenanceDescription
  ,(xpath('/p1:ProductDescription/p1:Features/wf:wheel/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar(256)
                                              AS Wheel
  ,(xpath('/p1:ProductDescription/p1:Features/wf:saddle/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar(256)
                                              AS Saddle
  ,(xpath('/p1:ProductDescription/p1:Features/wf:pedal/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar(256)
                                              AS Pedal
  ,(xpath('/p1:ProductDescription/p1:Features/wf:BikeFrame/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar
                                              AS BikeFrame
  ,(xpath('/p1:ProductDescription/p1:Features/wf:crankset/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription},{wf,http://www.adventure-works.com/schemas/OtherFeatures}}'))[1]::varchar(256)
                                              AS Crankset
  ,(xpath('/p1:ProductDescription/p1:Picture/p1:Angle/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                             AS PictureAngle
  ,(xpath('/p1:ProductDescription/p1:Picture/p1:Size/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                             AS PictureSize
  ,(xpath('/p1:ProductDescription/p1:Picture/p1:ProductPhotoID/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                             AS ProductPhotoID
  ,(xpath('/p1:ProductDescription/p1:Specifications/Material/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                 AS Material
  ,(xpath('/p1:ProductDescription/p1:Specifications/Color/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                 AS Color
  ,(xpath('/p1:ProductDescription/p1:Specifications/ProductLine/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                 AS ProductLine
  ,(xpath('/p1:ProductDescription/p1:Specifications/Style/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(256)
                                                 AS Style
  ,(xpath('/p1:ProductDescription/p1:Specifications/RiderExperience/text()', CatalogDescription, '{{p1,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelDescription}}' ))[1]::varchar(1024)
                                                 AS RiderExperience
  ,rowguid
  ,ModifiedDate
FROM Adventure.ProductModel
WHERE CatalogDescription IS NOT NULL;


-- Instructions have many locations, and locations have many steps
CREATE VIEW Adventure.vProductModelInstructions
AS
SELECT
    pm.ProductModelID
    ,pm.Name
    -- Access the overall Instructions xml brought through from %line 2938 and %line 2943
    ,(xpath('/ns:root/text()', pm.Instructions, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelManuInstructions}}'))[1]::varchar AS Instructions
    -- Bring out information about the location, broken out in %line 2945
    ,CAST((xpath('@LocationID', pm.MfgInstructions))[1]::varchar AS INTEGER) AS "LocationID"
    ,CAST((xpath('@SetupHours', pm.MfgInstructions))[1]::varchar AS DECIMAL(9, 4)) AS "SetupHours"
    ,CAST((xpath('@MachineHours', pm.MfgInstructions))[1]::varchar AS DECIMAL(9, 4)) AS "MachineHours"
    ,CAST((xpath('@LaborHours', pm.MfgInstructions))[1]::varchar AS DECIMAL(9, 4)) AS "LaborHours"
    ,CAST((xpath('@LotSize', pm.MfgInstructions))[1]::varchar AS INTEGER) AS "LotSize"
    -- Show specific detail about each step broken out in %line 2940
    ,(xpath('/step/text()', pm.Step))[1]::varchar(1024) AS "Step"
    ,pm.rowguid
    ,pm.ModifiedDate
FROM (SELECT locations.ProductModelID, locations.Name, locations.rowguid, locations.ModifiedDate
    ,locations.Instructions, locations.MfgInstructions
    -- Further break out the location information from the inner query below into individual steps
    ,UNNEST(xpath('step', locations.MfgInstructions)) AS Step
  FROM (SELECT
      -- Just pass these through so they can be referenced at the outermost query
      ProductModelID, Name, rowguid, ModifiedDate, Instructions
      -- And also break out Instructions into individual locations to pass up to the middle query
      ,UNNEST(xpath('/ns:root/ns:Location', Instructions, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/ProductModelManuInstructions}}')) AS MfgInstructions
    FROM Adventure.ProductModel) AS locations) AS pm;


CREATE VIEW Adventure.vSalesPerson
AS
SELECT
    s.BusinessEntityID
    ,p.Title
    ,p.FirstName
    ,p.MiddleName
    ,p.LastName
    ,p.Suffix
    ,e.JobTitle
    ,pp.PhoneNumber
    ,pnt.Name AS PhoneNumberType
    ,ea.EmailAddress
    ,p.EmailPromotion
    ,a.AddressLine1
    ,a.AddressLine2
    ,a.City
    ,sp.Name AS StateProvinceName
    ,a.PostalCode
    ,cr.Name AS CountryRegionName
    ,st.Name AS TerritoryName
    ,st.Group AS TerritoryGroup
    ,s.SalesQuota
    ,s.SalesYTD
    ,s.SalesLastYear
FROM Adventure.SalesPerson s
  INNER JOIN Adventure.Employee e
    ON e.BusinessEntityID = s.BusinessEntityID
  INNER JOIN Adventure.Person p
    ON p.BusinessEntityID = s.BusinessEntityID
  INNER JOIN Adventure.BusinessEntityAddress bea
    ON bea.BusinessEntityID = s.BusinessEntityID
  INNER JOIN Adventure.Address a
    ON a.AddressID = bea.AddressID
  INNER JOIN Adventure.StateProvince sp
    ON sp.StateProvinceID = a.StateProvinceID
  INNER JOIN Adventure.CountryRegion cr
    ON cr.CountryRegionCode = sp.CountryRegionCode
  LEFT OUTER JOIN Adventure.SalesTerritory st
    ON st.TerritoryID = s.TerritoryID
  LEFT OUTER JOIN Adventure.EmailAddress ea
    ON ea.BusinessEntityID = p.BusinessEntityID
  LEFT OUTER JOIN Adventure.PersonPhone pp
    ON pp.BusinessEntityID = p.BusinessEntityID
  LEFT OUTER JOIN Adventure.PhoneNumberType pnt
    ON pnt.PhoneNumberTypeID = pp.PhoneNumberTypeID;


-- This view provides the aggregated data that gets used in the PIVOTed view below
CREATE VIEW Adventure.vSalesPersonSalesByFiscalYearsData
AS
-- Of the 56 possible combinations of one of the 14 SalesPersons selling across one of
-- 4 FiscalYears, here we end up with 48 rows of aggregated data (since some sales people
-- were hired and started working in FY2012 or FY2013).
SELECT granular.SalesPersonID, granular.FullName, granular.JobTitle, granular.SalesTerritory, SUM(granular.SubTotal) AS SalesTotal, granular.FiscalYear
FROM
-- Brings back 3703 rows of data -- there are 3806 total sales done by a SalesPerson,
-- of which 103 do not have any sales territory.  This is fed into the outer GROUP BY
-- which results in 48 aggregated rows of sales data.
  (SELECT
      soh.SalesPersonID
      ,p.FirstName || ' ' || COALESCE(p.MiddleName || ' ', '') || p.LastName AS FullName
      ,e.JobTitle
      ,st.Name AS SalesTerritory
      ,soh.SubTotal
      ,EXTRACT(YEAR FROM soh.OrderDate + '6 months'::interval) AS FiscalYear
  FROM Adventure.SalesPerson sp
    INNER JOIN Adventure.SalesOrderHeader soh
      ON sp.BusinessEntityID = soh.SalesPersonID
    INNER JOIN Adventure.SalesTerritory st
      ON sp.TerritoryID = st.TerritoryID
    INNER JOIN Adventure.Employee e
      ON soh.SalesPersonID = e.BusinessEntityID
    INNER JOIN Adventure.Person p
      ON p.BusinessEntityID = sp.BusinessEntityID
  ) AS granular
GROUP BY granular.SalesPersonID, granular.FullName, granular.JobTitle, granular.SalesTerritory, granular.FiscalYear;

-- Note that this PIVOT query originally refered to years 2002-2004, which jived with
-- earlier versions of the AdventureWorks data.  Somewhere along the way all the dates
-- were cranked forward by exactly a decade, but this view wasn't updated, effectively
-- breaking it.  The hard-coded fiscal years below fix this issue.

-- Current sales data ranges from May 31, 2011 through June 30, 2014, so there's one
-- month of fiscal year 2011 data, but mostly FY 2012 through 2014.

-- This query properly shows no data for three of our sales people in 2012,
-- as they were hired during FY 2013.
CREATE VIEW Adventure.vSalesPersonSalesByFiscalYears
AS
SELECT * FROM crosstab(
'SELECT
    SalesPersonID
    ,FullName
    ,JobTitle
    ,SalesTerritory
    ,FiscalYear
    ,SalesTotal
FROM Adventure.vSalesPersonSalesByFiscalYearsData
ORDER BY 2,4'
-- This set of fiscal years could have dynamically come from a SELECT DISTINCT,
-- but we wanted to omit 2011 and also ...
,$$SELECT unnest('{2012,2013,2014}'::text[])$$)
-- ... still the FiscalYear values have to be hard-coded here.
AS SalesTotal ("SalesPersonID" integer, "FullName" text, "JobTitle" text, "SalesTerritory" text,
 "2012" DECIMAL(12, 4), "2013" DECIMAL(12, 4), "2014" DECIMAL(12, 4));


CREATE MATERIALIZED VIEW Adventure.vStateProvinceCountryRegion
AS
SELECT
    sp.StateProvinceID
    ,sp.StateProvinceCode
    ,sp.IsOnlyStateProvinceFlag
    ,sp.Name AS StateProvinceName
    ,sp.TerritoryID
    ,cr.CountryRegionCode
    ,cr.Name AS CountryRegionName
FROM Adventure.StateProvince sp
    INNER JOIN Adventure.CountryRegion cr
    ON sp.CountryRegionCode = cr.CountryRegionCode;

CREATE UNIQUE INDEX IX_vStateProvinceCountryRegion ON Adventure.vStateProvinceCountryRegion(StateProvinceID, CountryRegionCode);
CLUSTER Adventure.vStateProvinceCountryRegion USING IX_vStateProvinceCountryRegion;
-- If there are changes to either of these tables, this should be run to update the view:
--   REFRESH MATERIALIZED VIEW Adventure.vStateProvinceCountryRegion;


CREATE VIEW Adventure.vStoreWithDemographics
AS
SELECT
    BusinessEntityID
    ,Name
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:AnnualSales/text()', Demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS money)
                                       AS "AnnualSales"
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:AnnualRevenue/text()', Demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS money)
                                       AS "AnnualRevenue"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:BankName/text()', Demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(50)
                                  AS "BankName"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:BusinessType/text()', Demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(5)
                                  AS "BusinessType"
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:YearOpened/text()', Demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS integer)
                                       AS "YearOpened"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:Specialty/text()', Demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(50)
                                  AS "Specialty"
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:SquareFeet/text()', Demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS integer)
                                       AS "SquareFeet"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:Brands/text()', Demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(30)
                                  AS "Brands"
    ,UNNEST(xpath('/ns:StoreSurvey/ns:Internet/text()', Demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar(30)
                                  AS "Internet"
    ,CAST(UNNEST(xpath('/ns:StoreSurvey/ns:NumberEmployees/text()', Demographics, '{{ns,http://schemas.microsoft.com/sqlserver/2004/07/adventure-works/StoreSurvey}}'))::varchar AS integer)
                                       AS "NumberEmployees"
FROM Adventure.Store;


CREATE VIEW Adventure.vStoreWithContacts
AS
SELECT
    s.BusinessEntityID
    ,s.Name
    ,ct.Name AS ContactType
    ,p.Title
    ,p.FirstName
    ,p.MiddleName
    ,p.LastName
    ,p.Suffix
    ,pp.PhoneNumber
    ,pnt.Name AS PhoneNumberType
    ,ea.EmailAddress
    ,p.EmailPromotion
FROM Adventure.Store s
  INNER JOIN Adventure.BusinessEntityContact bec
    ON bec.BusinessEntityID = s.BusinessEntityID
  INNER JOIN Adventure.ContactType ct
    ON ct.ContactTypeID = bec.ContactTypeID
  INNER JOIN Adventure.Person p
    ON p.BusinessEntityID = bec.PersonID
  LEFT OUTER JOIN Adventure.EmailAddress ea
    ON ea.BusinessEntityID = p.BusinessEntityID
  LEFT OUTER JOIN Adventure.PersonPhone pp
    ON pp.BusinessEntityID = p.BusinessEntityID
  LEFT OUTER JOIN Adventure.PhoneNumberType pnt
    ON pnt.PhoneNumberTypeID = pp.PhoneNumberTypeID;


CREATE VIEW Adventure.vStoreWithAddresses
AS
SELECT
    s.BusinessEntityID
    ,s.Name
    ,at.Name AS AddressType
    ,a.AddressLine1
    ,a.AddressLine2
    ,a.City
    ,sp.Name AS StateProvinceName
    ,a.PostalCode
    ,cr.Name AS CountryRegionName
FROM Adventure.Store s
  INNER JOIN Adventure.BusinessEntityAddress bea
    ON bea.BusinessEntityID = s.BusinessEntityID
  INNER JOIN Adventure.Address a
    ON a.AddressID = bea.AddressID
  INNER JOIN Adventure.StateProvince sp
    ON sp.StateProvinceID = a.StateProvinceID
  INNER JOIN Adventure.CountryRegion cr
    ON cr.CountryRegionCode = sp.CountryRegionCode
  INNER JOIN Adventure.AddressType at
    ON at.AddressTypeID = bea.AddressTypeID;


CREATE VIEW Adventure.vVendorWithContacts
AS
SELECT
    v.BusinessEntityID
    ,v.Name
    ,ct.Name AS ContactType
    ,p.Title
    ,p.FirstName
    ,p.MiddleName
    ,p.LastName
    ,p.Suffix
    ,pp.PhoneNumber
    ,pnt.Name AS PhoneNumberType
    ,ea.EmailAddress
    ,p.EmailPromotion
FROM Adventure.Vendor v
  INNER JOIN Adventure.BusinessEntityContact bec
    ON bec.BusinessEntityID = v.BusinessEntityID
  INNER JOIN Adventure.ContactType ct
    ON ct.ContactTypeID = bec.ContactTypeID
  INNER JOIN Adventure.Person p
    ON p.BusinessEntityID = bec.PersonID
  LEFT OUTER JOIN Adventure.EmailAddress ea
    ON ea.BusinessEntityID = p.BusinessEntityID
  LEFT OUTER JOIN Adventure.PersonPhone pp
    ON pp.BusinessEntityID = p.BusinessEntityID
  LEFT OUTER JOIN Adventure.PhoneNumberType pnt
    ON pnt.PhoneNumberTypeID = pp.PhoneNumberTypeID;


CREATE VIEW Adventure.vVendorWithAddresses
AS
SELECT
    v.BusinessEntityID
    ,v.Name
    ,at.Name AS AddressType
    ,a.AddressLine1
    ,a.AddressLine2
    ,a.City
    ,sp.Name AS StateProvinceName
    ,a.PostalCode
    ,cr.Name AS CountryRegionName
FROM Adventure.Vendor v
  INNER JOIN Adventure.BusinessEntityAddress bea
    ON bea.BusinessEntityID = v.BusinessEntityID
  INNER JOIN Adventure.Address a
    ON a.AddressID = bea.AddressID
  INNER JOIN Adventure.StateProvince sp
    ON sp.StateProvinceID = a.StateProvinceID
  INNER JOIN Adventure.CountryRegion cr
    ON cr.CountryRegionCode = sp.CountryRegionCode
  INNER JOIN Adventure.AddressType at
    ON at.AddressTypeID = bea.AddressTypeID;


-- Convenience views

CREATE SCHEMA aw
  CREATE VIEW aw_a AS SELECT addressid AS id, * FROM Adventure.address
  CREATE VIEW aw_at AS SELECT addresstypeid AS id, * FROM Adventure.addresstype
  CREATE VIEW aw_be AS SELECT businessentityid AS id, * FROM Adventure.businessentity
  CREATE VIEW aw_bea AS SELECT businessentityid AS id, * FROM Adventure.businessentityaddress
  CREATE VIEW aw_bec AS SELECT businessentityid AS id, * FROM Adventure.businessentitycontact
  CREATE VIEW aw_ct AS SELECT contacttypeid AS id, * FROM Adventure.contacttype
  CREATE VIEW aw_cr AS SELECT * FROM Adventure.countryregion
  CREATE VIEW aw_e AS SELECT emailaddressid AS id, * FROM Adventure.emailaddress
  CREATE VIEW aw_pa AS SELECT businessentityid AS id, * FROM Adventure.password
  CREATE VIEW aw_p AS SELECT businessentityid AS id, * FROM Adventure.person
  CREATE VIEW aw_pp AS SELECT businessentityid AS id, * FROM Adventure.personphone
  CREATE VIEW aw_pnt AS SELECT phonenumbertypeid AS id, * FROM Adventure.phonenumbertype
  CREATE VIEW aw_sp AS SELECT stateprovinceid AS id, * FROM Adventure.stateprovince
  CREATE VIEW aw_d AS SELECT departmentid AS id, * FROM adventure.department
  CREATE VIEW aw_edh AS SELECT businessentityid AS id, * FROM adventure.employeedepartmenthistory
  CREATE VIEW aw_eph AS SELECT businessentityid AS id, * FROM adventure.employeepayhistory
  CREATE VIEW aw_jc AS SELECT jobcandidateid AS id, * FROM adventure.jobcandidate
  CREATE VIEW aw_s AS SELECT shiftid AS id, * FROM adventure.shift
  CREATE VIEW aw_bom AS SELECT billofmaterialsid AS id, * FROM adventure.billofmaterials
  CREATE VIEW aw_i AS SELECT illustrationid AS id, * FROM adventure.illustration
  CREATE VIEW aw_l AS SELECT locationid AS id, * FROM adventure.location
  CREATE VIEW aw_pc AS SELECT productcategoryid AS id, * FROM adventure.productcategory
  CREATE VIEW aw_pch AS SELECT productid AS id, * FROM adventure.productcosthistory
  CREATE VIEW aw_pd AS SELECT productdescriptionid AS id, * FROM adventure.productdescription
  CREATE VIEW aw_pdoc AS SELECT productid AS id, * FROM adventure.productdocument
  CREATE VIEW aw_pi AS SELECT productid AS id, * FROM adventure.productinventory
  CREATE VIEW aw_plph AS SELECT productid AS id, * FROM adventure.productlistpricehistory
  CREATE VIEW aw_pm AS SELECT productmodelid AS id, * FROM adventure.productmodel
  CREATE VIEW aw_pmi AS SELECT * FROM adventure.productmodelillustration
  CREATE VIEW aw_pmpdc AS SELECT * FROM adventure.productmodelproductdescriptionculture
  CREATE VIEW aw_ppp AS SELECT * FROM adventure.productproductphoto
  CREATE VIEW aw_pr AS SELECT productreviewid AS id, * FROM adventure.productreview
  CREATE VIEW aw_psc AS SELECT productsubcategoryid AS id, * FROM adventure.productsubcategory
  CREATE VIEW aw_sr AS SELECT scrapreasonid AS id, * FROM adventure.scrapreason
  CREATE VIEW aw_th AS SELECT transactionid AS id, * FROM adventure.transactionhistory
  CREATE VIEW aw_tha AS SELECT transactionid AS id, * FROM adventure.transactionhistoryarchive
  CREATE VIEW aw_um AS SELECT unitmeasurecode AS id, * FROM adventure.unitmeasure
  CREATE VIEW aw_w AS SELECT workorderid AS id, * FROM adventure.workorder
  CREATE VIEW aw_wr AS SELECT workorderid AS id, * FROM adventure.workorderrouting
  CREATE VIEW aw_pv AS SELECT productid AS id, * FROM adventure.productvendor
  CREATE VIEW aw_pod AS SELECT purchaseorderdetailid AS id, * FROM adventure.purchaseorderdetail
  CREATE VIEW aw_poh AS SELECT purchaseorderid AS id, * FROM adventure.purchaseorderheader
  CREATE VIEW aw_sm AS SELECT shipmethodid AS id, * FROM adventure.shipmethod
  CREATE VIEW aw_v AS SELECT businessentityid AS id, * FROM adventure.vendor
  CREATE VIEW aw_crc AS SELECT * FROM adventure.countryregioncurrency
  CREATE VIEW aw_cc AS SELECT creditcardid AS id, * FROM adventure.creditcard
  CREATE VIEW aw_cu AS SELECT currencycode AS id, * FROM adventure.currency
  CREATE VIEW aw_c AS SELECT customerid AS id, * FROM adventure.customer
  CREATE VIEW aw_pcc AS SELECT businessentityid AS id, * FROM adventure.personcreditcard
  CREATE VIEW aw_sod AS SELECT salesorderdetailid AS id, * FROM adventure.salesorderdetail
  CREATE VIEW aw_soh AS SELECT salesorderid AS id, * FROM adventure.salesorderheader
  CREATE VIEW aw_sohsr AS SELECT * FROM adventure.salesorderheadersalesreason
  CREATE VIEW aw_spqh AS SELECT businessentityid AS id, * FROM adventure.salespersonquotahistory
  CREATE VIEW aw_tr AS SELECT salestaxrateid AS id, * FROM adventure.salestaxrate
  CREATE VIEW aw_st AS SELECT territoryid AS id, * FROM adventure.salesterritory
  CREATE VIEW aw_sth AS SELECT territoryid AS id, * FROM adventure.salesterritoryhistory
  CREATE VIEW aw_sci AS SELECT shoppingcartitemid AS id, * FROM adventure.shoppingcartitem
  CREATE VIEW aw_so AS SELECT specialofferid AS id, * FROM adventure.specialoffer
  CREATE VIEW aw_sop AS SELECT specialofferid AS id, * FROM adventure.specialofferproduct
;

CREATE TABLE Adventure.StupidlyBigTable (
    id SERIAL PRIMARY KEY,
    user_id INT,
    product_id INT,
    order_id INT,
    customer_age INT,
    employee_id INT,
    store_id INT,
    inventory_id INT,
    sales_id INT,
    purchase_id INT,
    invoice_id INT,
    user_name VARCHAR(255),
    product_name VARCHAR(255),
    order_status VARCHAR(255),
    customer_name VARCHAR(255),
    employee_name VARCHAR(255),
    store_location VARCHAR(255),
    inventory_status VARCHAR(255),
    sales_representative VARCHAR(255),
    purchase_status VARCHAR(255),
    invoice_status VARCHAR(255),
    user_email VARCHAR(255),
    product_description VARCHAR(255),
    order_description VARCHAR(255),
    customer_email VARCHAR(255),
    employee_email VARCHAR(255),
    store_description VARCHAR(255),
    inventory_description VARCHAR(255),
    sales_description VARCHAR(255),
    purchase_description VARCHAR(255),
    invoice_description VARCHAR(255),
    product_name_description VARCHAR(255),
    order_status_description VARCHAR(255),
    customer_name_description VARCHAR(255),
    employee_name_description VARCHAR(255),
    store_location_description VARCHAR(255),
    inventory_status_description VARCHAR(255),
    sales_representative_description VARCHAR(255),
    purchase_status_description VARCHAR(255),
    invoice_status_description VARCHAR(255),
    user_email_description VARCHAR(255),
    product_description_description VARCHAR(255),
    order_description_description VARCHAR(255),
    customer_email_description VARCHAR(255),
    employee_email_description VARCHAR(255),
    store_description_description VARCHAR(255),
    inventory_description_description VARCHAR(255),
    sales_description_description VARCHAR(255),
    purchase_description_description VARCHAR(255),
    invoice_description_description VARCHAR(255),
    product_name_description_description VARCHAR(255),
    order_status_description_description VARCHAR(255),
    customer_name_description_description VARCHAR(255),
    employee_name_description_description VARCHAR(255),
    store_location_description_description VARCHAR(255),
    inventory_status_description_description VARCHAR(255),
    sales_representative_description_description VARCHAR(255),
    purchase_status_description_description VARCHAR(255),
    invoice_status_description_description VARCHAR(255),
    user_email_description_description VARCHAR(255),
    product_description_description_description VARCHAR(255),
    order_description_description_description VARCHAR(255),
    customer_email_description_description VARCHAR(255),
    employee_email_description_description VARCHAR(255),
    store_description_description_description VARCHAR(255),
    inventory_description_description_description VARCHAR(255),
    sales_description_description_description VARCHAR(255),
    purchase_description_description_description VARCHAR(255),
    invoice_description_description_description VARCHAR(255),
    product_name_description_description_description VARCHAR(255),
    order_status_description_description_description VARCHAR(255),
    customer_name_description_description_description VARCHAR(255),
    employee_name_description_description_description VARCHAR(255),
    store_location_description_description_description VARCHAR(255),
    inventory_status_description_description_description VARCHAR(255),
    sales_representative_description_description_description VARCHAR(255),
    purchase_status_description_description_description VARCHAR(255),
    invoice_status_description_description_description VARCHAR(255),
    user_email_description_description_description VARCHAR(255),
    product_description_description_description_description VARCHAR(255),
    order_description_description_description_description VARCHAR(255),
    customer_email_description_description_description VARCHAR(255),
    employee_email_description_description_description VARCHAR(255),
    store_description_description_description_description VARCHAR(255),
    inventory_description_description_description_description VARCHAR(255),
    sales_description_description_description_description VARCHAR(255),
    purchase_description_description_description_description VARCHAR(255),
    invoice_description_description_description_description VARCHAR(255)
);

CREATE TABLE Adventure.StupidlyBigTable_Copy2 (
    id SERIAL PRIMARY KEY,
    user_id INT,
    product_id INT,
    order_id INT,
    customer_age INT,
    employee_id INT,
    store_id INT,
    inventory_id INT,
    sales_id INT,
    purchase_id INT,
    invoice_id INT,
    user_name VARCHAR(255),
    product_name VARCHAR(255),
    order_status VARCHAR(255),
    customer_name VARCHAR(255),
    employee_name VARCHAR(255),
    store_location VARCHAR(255),
    inventory_status VARCHAR(255),
    sales_representative VARCHAR(255),
    purchase_status VARCHAR(255),
    invoice_status VARCHAR(255),
    user_email VARCHAR(255),
    product_description VARCHAR(255),
    order_description VARCHAR(255),
    customer_email VARCHAR(255),
    employee_email VARCHAR(255),
    store_description VARCHAR(255),
    inventory_description VARCHAR(255),
    sales_description VARCHAR(255),
    purchase_description VARCHAR(255),
    invoice_description VARCHAR(255),
    product_name_description VARCHAR(255),
    order_status_description VARCHAR(255),
    customer_name_description VARCHAR(255),
    employee_name_description VARCHAR(255),
    store_location_description VARCHAR(255),
    inventory_status_description VARCHAR(255),
    sales_representative_description VARCHAR(255),
    purchase_status_description VARCHAR(255),
    invoice_status_description VARCHAR(255),
    user_email_description VARCHAR(255),
    product_description_description VARCHAR(255),
    order_description_description VARCHAR(255),
    customer_email_description VARCHAR(255),
    employee_email_description VARCHAR(255),
    store_description_description VARCHAR(255),
    inventory_description_description VARCHAR(255),
    sales_description_description VARCHAR(255),
    purchase_description_description VARCHAR(255),
    invoice_description_description VARCHAR(255),
    product_name_description_description VARCHAR(255),
    order_status_description_description VARCHAR(255),
    customer_name_description_description VARCHAR(255),
    employee_name_description_description VARCHAR(255),
    store_location_description_description VARCHAR(255),
    inventory_status_description_description VARCHAR(255),
    sales_representative_description_description VARCHAR(255),
    purchase_status_description_description VARCHAR(255),
    invoice_status_description_description VARCHAR(255),
    user_email_description_description VARCHAR(255),
    product_description_description_description VARCHAR(255),
    order_description_description_description VARCHAR(255),
    customer_email_description_description VARCHAR(255),
    employee_email_description_description VARCHAR(255),
    store_description_description_description VARCHAR(255),
    inventory_description_description_description VARCHAR(255),
    sales_description_description_description VARCHAR(255),
    purchase_description_description_description VARCHAR(255),
    invoice_description_description_description VARCHAR(255),
    product_name_description_description_description VARCHAR(255),
    order_status_description_description_description VARCHAR(255),
    customer_name_description_description_description VARCHAR(255),
    employee_name_description_description_description VARCHAR(255),
    store_location_description_description_description VARCHAR(255),
    inventory_status_description_description_description VARCHAR(255),
    sales_representative_description_description_description VARCHAR(255),
    purchase_status_description_description_description VARCHAR(255),
    invoice_status_description_description_description VARCHAR(255),
    user_email_description_description_description VARCHAR(255),
    product_description_description_description_description VARCHAR(255),
    order_description_description_description_description VARCHAR(255),
    customer_email_description_description_description VARCHAR(255),
    employee_email_description_description_description VARCHAR(255),
    store_description_description_description_description VARCHAR(255),
    inventory_description_description_description_description VARCHAR(255),
    sales_description_description_description_description VARCHAR(255),
    purchase_description_description_description_description VARCHAR(255),
    invoice_description_description_description_description VARCHAR(255)
);

CREATE TABLE Adventure.StupidlyBigTable_Copy3 (
    id SERIAL PRIMARY KEY,
    user_id INT,
    product_id INT,
    order_id INT,
    customer_age INT,
    employee_id INT,
    store_id INT,
    inventory_id INT,
    sales_id INT,
    purchase_id INT,
    invoice_id INT,
    user_name VARCHAR(255),
    product_name VARCHAR(255),
    order_status VARCHAR(255),
    customer_name VARCHAR(255),
    employee_name VARCHAR(255),
    store_location VARCHAR(255),
    inventory_status VARCHAR(255),
    sales_representative VARCHAR(255),
    purchase_status VARCHAR(255),
    invoice_status VARCHAR(255),
    user_email VARCHAR(255),
    product_description VARCHAR(255),
    order_description VARCHAR(255),
    customer_email VARCHAR(255),
    employee_email VARCHAR(255),
    store_description VARCHAR(255),
    inventory_description VARCHAR(255),
    sales_description VARCHAR(255),
    purchase_description VARCHAR(255),
    invoice_description VARCHAR(255),
    product_name_description VARCHAR(255),
    order_status_description VARCHAR(255),
    customer_name_description VARCHAR(255),
    employee_name_description VARCHAR(255),
    store_location_description VARCHAR(255),
    inventory_status_description VARCHAR(255),
    sales_representative_description VARCHAR(255),
    purchase_status_description VARCHAR(255),
    invoice_status_description VARCHAR(255),
    user_email_description VARCHAR(255),
    product_description_description VARCHAR(255),
    order_description_description VARCHAR(255),
    customer_email_description VARCHAR(255),
    employee_email_description VARCHAR(255),
    store_description_description VARCHAR(255),
    inventory_description_description VARCHAR(255),
    sales_description_description VARCHAR(255),
    purchase_description_description VARCHAR(255),
    invoice_description_description VARCHAR(255),
    product_name_description_description VARCHAR(255),
    order_status_description_description VARCHAR(255),
    customer_name_description_description VARCHAR(255),
    employee_name_description_description VARCHAR(255),
    store_location_description_description VARCHAR(255),
    inventory_status_description_description VARCHAR(255),
    sales_representative_description_description VARCHAR(255),
    purchase_status_description_description VARCHAR(255),
    invoice_status_description_description VARCHAR(255),
    user_email_description_description VARCHAR(255),
    product_description_description_description VARCHAR(255),
    order_description_description_description VARCHAR(255),
    customer_email_description_description VARCHAR(255),
    employee_email_description_description VARCHAR(255),
    store_description_description_description VARCHAR(255),
    inventory_description_description_description VARCHAR(255),
    sales_description_description_description VARCHAR(255),
    purchase_description_description_description VARCHAR(255),
    invoice_description_description_description VARCHAR(255),
    product_name_description_description_description VARCHAR(255),
    order_status_description_description_description VARCHAR(255),
    customer_name_description_description_description VARCHAR(255),
    employee_name_description_description_description VARCHAR(255),
    store_location_description_description_description VARCHAR(255),
    inventory_status_description_description_description VARCHAR(255),
    sales_representative_description_description_description VARCHAR(255),
    purchase_status_description_description_description VARCHAR(255),
    invoice_status_description_description_description VARCHAR(255),
    user_email_description_description_description VARCHAR(255),
    product_description_description_description_description VARCHAR(255),
    order_description_description_description_description VARCHAR(255),
    customer_email_description_description_description VARCHAR(255),
    employee_email_description_description_description VARCHAR(255),
    store_description_description_description_description VARCHAR(255),
    inventory_description_description_description_description VARCHAR(255),
    sales_description_description_description_description VARCHAR(255),
    purchase_description_description_description_description VARCHAR(255),
    invoice_description_description_description_description VARCHAR(255)
);

CREATE TABLE Adventure.StupidlyBigTable_Copy4 (
    id SERIAL PRIMARY KEY,
    user_id INT,
    product_id INT,
    order_id INT,
    customer_age INT,
    employee_id INT,
    store_id INT,
    inventory_id INT,
    sales_id INT,
    purchase_id INT,
    invoice_id INT,
    user_name VARCHAR(255),
    product_name VARCHAR(255),
    order_status VARCHAR(255),
    customer_name VARCHAR(255),
    employee_name VARCHAR(255),
    store_location VARCHAR(255),
    inventory_status VARCHAR(255),
    sales_representative VARCHAR(255),
    purchase_status VARCHAR(255),
    invoice_status VARCHAR(255),
    user_email VARCHAR(255),
    product_description VARCHAR(255),
    order_description VARCHAR(255),
    customer_email VARCHAR(255),
    employee_email VARCHAR(255),
    store_description VARCHAR(255),
    inventory_description VARCHAR(255),
    sales_description VARCHAR(255),
    purchase_description VARCHAR(255),
    invoice_description VARCHAR(255),
    product_name_description VARCHAR(255),
    order_status_description VARCHAR(255),
    customer_name_description VARCHAR(255),
    employee_name_description VARCHAR(255),
    store_location_description VARCHAR(255),
    inventory_status_description VARCHAR(255),
    sales_representative_description VARCHAR(255),
    purchase_status_description VARCHAR(255),
    invoice_status_description VARCHAR(255),
    user_email_description VARCHAR(255),
    product_description_description VARCHAR(255),
    order_description_description VARCHAR(255),
    customer_email_description VARCHAR(255),
    employee_email_description VARCHAR(255),
    store_description_description VARCHAR(255),
    inventory_description_description VARCHAR(255),
    sales_description_description VARCHAR(255),
    purchase_description_description VARCHAR(255),
    invoice_description_description VARCHAR(255),
    product_name_description_description VARCHAR(255),
    order_status_description_description VARCHAR(255),
    customer_name_description_description VARCHAR(255),
    employee_name_description_description VARCHAR(255),
    store_location_description_description VARCHAR(255),
    inventory_status_description_description VARCHAR(255),
    sales_representative_description_description VARCHAR(255),
    purchase_status_description_description VARCHAR(255),
    invoice_status_description_description VARCHAR(255),
    user_email_description_description VARCHAR(255),
    product_description_description_description VARCHAR(255),
    order_description_description_description VARCHAR(255),
    customer_email_description_description VARCHAR(255),
    employee_email_description_description VARCHAR(255),
    store_description_description_description VARCHAR(255),
    inventory_description_description_description VARCHAR(255),
    sales_description_description_description VARCHAR(255),
    purchase_description_description_description VARCHAR(255),
    invoice_description_description_description VARCHAR(255),
    product_name_description_description_description VARCHAR(255),
    order_status_description_description_description VARCHAR(255),
    customer_name_description_description_description VARCHAR(255),
    employee_name_description_description_description VARCHAR(255),
    store_location_description_description_description VARCHAR(255),
    inventory_status_description_description_description VARCHAR(255),
    sales_representative_description_description_description VARCHAR(255),
    purchase_status_description_description_description VARCHAR(255),
    invoice_status_description_description_description VARCHAR(255),
    user_email_description_description_description VARCHAR(255),
    product_description_description_description_description VARCHAR(255),
    order_description_description_description_description VARCHAR(255),
    customer_email_description_description_description VARCHAR(255),
    employee_email_description_description_description VARCHAR(255),
    store_description_description_description_description VARCHAR(255),
    inventory_description_description_description_description VARCHAR(255),
    sales_description_description_description_description VARCHAR(255),
    purchase_description_description_description_description VARCHAR(255),
    invoice_description_description_description_description VARCHAR(255)
);

CREATE TABLE Adventure.StupidlyBigTable_Copy5 (
    id SERIAL PRIMARY KEY,
    user_id INT,
    product_id INT,
    order_id INT,
    customer_age INT,
    employee_id INT,
    store_id INT,
    inventory_id INT,
    sales_id INT,
    purchase_id INT,
    invoice_id INT,
    user_name VARCHAR(255),
    product_name VARCHAR(255),
    order_status VARCHAR(255),
    customer_name VARCHAR(255),
    employee_name VARCHAR(255),
    store_location VARCHAR(255),
    inventory_status VARCHAR(255),
    sales_representative VARCHAR(255),
    purchase_status VARCHAR(255),
    invoice_status VARCHAR(255),
    user_email VARCHAR(255),
    product_description VARCHAR(255),
    order_description VARCHAR(255),
    customer_email VARCHAR(255),
    employee_email VARCHAR(255),
    store_description VARCHAR(255),
    inventory_description VARCHAR(255),
    sales_description VARCHAR(255),
    purchase_description VARCHAR(255),
    invoice_description VARCHAR(255),
    product_name_description VARCHAR(255),
    order_status_description VARCHAR(255),
    customer_name_description VARCHAR(255),
    employee_name_description VARCHAR(255),
    store_location_description VARCHAR(255),
    inventory_status_description VARCHAR(255),
    sales_representative_description VARCHAR(255),
    purchase_status_description VARCHAR(255),
    invoice_status_description VARCHAR(255),
    user_email_description VARCHAR(255),
    product_description_description VARCHAR(255),
    order_description_description VARCHAR(255),
    customer_email_description VARCHAR(255),
    employee_email_description VARCHAR(255),
    store_description_description VARCHAR(255),
    inventory_description_description VARCHAR(255),
    sales_description_description VARCHAR(255),
    purchase_description_description VARCHAR(255),
    invoice_description_description VARCHAR(255),
    product_name_description_description VARCHAR(255),
    order_status_description_description VARCHAR(255),
    customer_name_description_description VARCHAR(255),
    employee_name_description_description VARCHAR(255),
    store_location_description_description VARCHAR(255),
    inventory_status_description_description VARCHAR(255),
    sales_representative_description_description VARCHAR(255),
    purchase_status_description_description VARCHAR(255),
    invoice_status_description_description VARCHAR(255),
    user_email_description_description VARCHAR(255),
    product_description_description_description VARCHAR(255),
    order_description_description_description VARCHAR(255),
    customer_email_description_description VARCHAR(255),
    employee_email_description_description VARCHAR(255),
    store_description_description_description VARCHAR(255),
    inventory_description_description_description VARCHAR(255),
    sales_description_description_description VARCHAR(255),
    purchase_description_description_description VARCHAR(255),
    invoice_description_description_description VARCHAR(255),
    product_name_description_description_description VARCHAR(255),
    order_status_description_description_description VARCHAR(255),
    customer_name_description_description_description VARCHAR(255),
    employee_name_description_description_description VARCHAR(255),
    store_location_description_description_description VARCHAR(255),
    inventory_status_description_description_description VARCHAR(255),
    sales_representative_description_description_description VARCHAR(255),
    purchase_status_description_description_description VARCHAR(255),
    invoice_status_description_description_description VARCHAR(255),
    user_email_description_description_description VARCHAR(255),
    product_description_description_description_description VARCHAR(255),
    order_description_description_description_description VARCHAR(255),
    customer_email_description_description_description VARCHAR(255),
    employee_email_description_description_description VARCHAR(255),
    store_description_description_description_description VARCHAR(255),
    inventory_description_description_description_description VARCHAR(255),
    sales_description_description_description_description VARCHAR(255),
    purchase_description_description_description_description VARCHAR(255),
    invoice_description_description_description_description VARCHAR(255)
);
-- Ensure that Perry Skountrianos' change for Türkiye is implemented properly if it was intended
-- https://github.com/microsoft/sql-server-samples/commit/cca0f1920e3bec5b9cef97e1fdc32b6883526581
-- Fix any messed up one if such a thing exists and is not proper unicode
UPDATE Adventure.countryregion SET name='T' || U&'\00FC' || 'rkiye' WHERE name='Türkiye';
-- Optionally you can uncomment this to update "Turkey" to the unicode-appropriate rendition of "Türkiye"
-- UPDATE Adventure.countryregion SET name='T' || U&'\00FC' || 'rkiye' WHERE name='Turkey';

-- If you intend to use this data with The Brick (or some other Rails project) then you may want
-- to rename the "class" column in Adventure.Product so it does not interfere with Ruby's reserved
-- keyword "class":
-- ALTER TABLE adventure.product RENAME COLUMN class TO class_;
\pset tuples_only off

