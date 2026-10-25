# Nko's Driving School Management Database

A comprehensive, normalized relational database system built to manage and track the complete operational lifecycle of a multi-branch driving school[span_2](start_span)[span_2](end_span)[span_3](start_span)[span_3](end_span).

## 🛠️ Tech Stack
* **Database Engine:** MySQL 8.0+[span_4](start_span)[span_4](end_span)
* **Management Tool:** MySQL Workbench[span_5](start_span)[span_5](end_span)

---

## 📌 Project Overview
This project models the daily operations of a driving school across multiple branches (e.g., Delft and Langa)[span_6](start_span)[span_6](end_span)[span_7](start_span)[span_7](end_span). It manages learners, instructor rosters, vehicle fleets, lesson bookings, financial transactions, and official licence test attempts[span_8](start_span)[span_8](end_span).

### Key Features & Architecture
* **Relational Schema (16 Tables):** Fully normalized schema separating entity concerns across 16 interconnected tables (Learner, Instructor_Driver, Vehicle, Booking, Lesson, Payment, Test_Attempt, etc.)[span_9](start_span)[span_9](end_span)[span_10](start_span)[span_10](end_span).
* **Business Logic Enforcement (Triggers & Constraints):**
  * **Lesson Scheduling Gap:** Custom `BEFORE INSERT` trigger enforcing a 30-minute buffer gap between back-to-back lessons for instructors and vehicles[span_11](start_span)[span_11](end_span)[span_12](start_span)[span_12](end_span).
    * **Automated Odometer Tracking:** `AFTER INSERT` trigger that logs vehicle mileage into `Vehicle_Odometer_Log` whenever a lesson is completed[span_13](start_span)[span_13](end_span)[span_14](start_span)[span_14](end_span).
      * **Test Attempt Rules:** Trigger validating consecutive numbering of test attempts, blocking attempts after a pass, and flagging 4th+ attempts as chargeable[span_15](start_span)[span_15](end_span)[span_16](start_span)[span_16](end_span).
        * **Data Integrity Rules:** `CHECK` constraints prohibiting cash payments and enforcing valid cancellation timestamps[span_17](start_span)[span_17](end_span)[span_18](start_span)[span_18](end_span)[span_19](start_span)[span_19](end_span).
        * **Operational Reporting:** Queries for payment statements, vehicle maintenance due alerts, and instructor lesson metrics using multi-table `JOIN`s, `GROUP BY`, and `HAVING` clauses[span_20](start_span)[span_20](end_span)[span_21](start_span)[span_21](end_span)[span_22](start_span)[span_22](end_span)[span_23](start_span)[span_23](end_span).

        ---

        ## 📂 File Structure
        * `01_Schema_and_Sample_Data.sql`: Full DDL and DML script to drop, build, and seed the entire database with sample data[span_24](start_span)[span_24](end_span)[span_25](start_span)[span_25](end_span).
