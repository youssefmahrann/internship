-- ============================================================
-- COMP1044 Internship Result Management System
-- Database: comp1044_irms
-- ============================================================

CREATE DATABASE IF NOT EXISTS comp1044_irms
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE comp1044_irms;

-- ============================================================
-- TABLE: programmes
-- ============================================================
CREATE TABLE programmes (
    programme_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    programme_code  VARCHAR(20)  NOT NULL UNIQUE,
    programme_name  VARCHAR(150) NOT NULL
) ENGINE=InnoDB;

-- ============================================================
-- TABLE: users  (Admin + Assessor accounts)
-- ============================================================
CREATE TABLE users (
    user_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name     VARCHAR(120) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role          ENUM('admin','assessor') NOT NULL DEFAULT 'assessor',
    is_active     TINYINT(1)   NOT NULL DEFAULT 1,
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================
-- TABLE: students
-- ============================================================
CREATE TABLE students (
    student_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_number VARCHAR(20)  NOT NULL UNIQUE,
    full_name      VARCHAR(120) NOT NULL,
    email          VARCHAR(150),
    programme_id   INT UNSIGNED NOT NULL,
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_student_programme
        FOREIGN KEY (programme_id) REFERENCES programmes(programme_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- TABLE: companies
-- ============================================================
CREATE TABLE companies (
    company_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    company_name VARCHAR(200) NOT NULL,
    address      TEXT,
    industry     VARCHAR(100)
) ENGINE=InnoDB;

-- ============================================================
-- TABLE: internships
-- ============================================================
CREATE TABLE internships (
    internship_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id     INT UNSIGNED NOT NULL,
    company_id     INT UNSIGNED NOT NULL,
    assessor_id    INT UNSIGNED NOT NULL,
    start_date     DATE,
    end_date       DATE,
    academic_year  VARCHAR(20)  NOT NULL,
    status         ENUM('ongoing','completed','withdrawn') NOT NULL DEFAULT 'ongoing',
    created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_internship_student
        FOREIGN KEY (student_id)  REFERENCES students(student_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_internship_company
        FOREIGN KEY (company_id)  REFERENCES companies(company_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_internship_assessor
        FOREIGN KEY (assessor_id) REFERENCES users(user_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- TABLE: assessment_criteria  (fixed, managed by admin)
-- ============================================================
CREATE TABLE assessment_criteria (
    criteria_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    criteria_name VARCHAR(200) NOT NULL,
    weightage     DECIMAL(5,2) NOT NULL   -- stored as percentage e.g. 10.00
) ENGINE=InnoDB;

-- ============================================================
-- TABLE: assessments  (one row per internship)
-- ============================================================
CREATE TABLE assessments (
    assessment_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    internship_id  INT UNSIGNED NOT NULL UNIQUE,
    assessor_id    INT UNSIGNED NOT NULL,
    overall_comment TEXT,
    total_score    DECIMAL(6,2) GENERATED ALWAYS AS (NULL) VIRTUAL,
    submitted_at   DATETIME,
    created_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_assessment_internship
        FOREIGN KEY (internship_id) REFERENCES internships(internship_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_assessment_assessor
        FOREIGN KEY (assessor_id)   REFERENCES users(user_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Drop the virtual column; we will compute total in PHP / a view instead
ALTER TABLE assessments DROP COLUMN total_score;

-- ============================================================
-- TABLE: assessment_scores  (one row per criterion per assessment)
-- ============================================================
CREATE TABLE assessment_scores (
    score_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    assessment_id INT UNSIGNED NOT NULL,
    criteria_id   INT UNSIGNED NOT NULL,
    score         DECIMAL(5,2) NOT NULL CHECK (score >= 0 AND score <= 100),
    comment       TEXT,
    UNIQUE KEY uq_assessment_criteria (assessment_id, criteria_id),
    CONSTRAINT fk_score_assessment
        FOREIGN KEY (assessment_id) REFERENCES assessments(assessment_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_score_criteria
        FOREIGN KEY (criteria_id)   REFERENCES assessment_criteria(criteria_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
-- VIEW: v_assessment_totals
-- Computes weighted total per assessment
-- ============================================================
CREATE OR REPLACE VIEW v_assessment_totals AS
SELECT
    a.assessment_id,
    a.internship_id,
    a.assessor_id,
    a.overall_comment,
    a.submitted_at,
    ROUND(
        SUM(s.score * c.weightage / 100), 2
    ) AS total_score
FROM assessments a
JOIN assessment_scores s ON s.assessment_id = a.assessment_id
JOIN assessment_criteria c ON c.criteria_id  = s.criteria_id
GROUP BY
    a.assessment_id, a.internship_id, a.assessor_id,
    a.overall_comment, a.submitted_at;

-- ============================================================
-- SEED DATA
-- ============================================================

-- Programmes
INSERT INTO programmes (programme_code, programme_name) VALUES
('CS',   'Bachelor of Computer Science'),
('IT',   'Bachelor of Information Technology'),
('SE',   'Bachelor of Software Engineering'),
('NET',  'Bachelor of Computer Networks'),
('DS',   'Bachelor of Data Science');

-- Admin account  (password: Admin@1234)
INSERT INTO users (full_name, email, password_hash, role) VALUES
('System Administrator', 'admin@university.edu',
 '$2y$12$YqwZXkL9Hm3VtRpO5sNuAe8GcJfDnMbQ1KiWvEoT4xSjAhPzLuCr6', 'admin');

-- Assessor accounts  (password: Pass@1234 for all)
INSERT INTO users (full_name, email, password_hash, role) VALUES
('Dr. Ahmad Razali',   'ahmad.razali@university.edu',   '$2y$12$YqwZXkL9Hm3VtRpO5sNuAe8GcJfDnMbQ1KiWvEoT4xSjAhPzLuCr6', 'assessor'),
('Dr. Siti Nurhaliza', 'siti.nurhaliza@university.edu', '$2y$12$YqwZXkL9Hm3VtRpO5sNuAe8GcJfDnMbQ1KiWvEoT4xSjAhPzLuCr6', 'assessor'),
('Mr. Lim Wei Loon',   'lim.weiloon@university.edu',    '$2y$12$YqwZXkL9Hm3VtRpO5sNuAe8GcJfDnMbQ1KiWvEoT4xSjAhPzLuCr6', 'assessor'),
('Ms. Priya Menon',    'priya.menon@university.edu',    '$2y$12$YqwZXkL9Hm3VtRpO5sNuAe8GcJfDnMbQ1KiWvEoT4xSjAhPzLuCr6', 'assessor');

-- Assessment Criteria (FIXED weightages as per spec)
INSERT INTO assessment_criteria (criteria_name, weightage) VALUES
('Undertaking Tasks/Projects',                      10.00),
('Health and Safety Requirements at the Workplace', 10.00),
('Connectivity and Use of Theoretical Knowledge',   10.00),
('Presentation of the Report as a Written Document',15.00),
('Clarity of Language and Illustration',            10.00),
('Lifelong Learning Activities',                    15.00),
('Project Management',                              15.00),
('Time Management',                                 15.00);

-- Companies
INSERT INTO companies (company_name, address, industry) VALUES
('Petronas Digital Sdn Bhd',     'Kuala Lumpur',           'Oil & Gas Technology'),
('Maybank Group Technology',     'Kuala Lumpur',           'Financial Technology'),
('TM Research & Development',    'Cyberjaya, Selangor',    'Telecommunications'),
('Maxis Berhad',                 'Kuala Lumpur',           'Telecommunications'),
('Dell Technologies Malaysia',   'Cyberjaya, Selangor',    'Information Technology'),
('IBM Malaysia Sdn Bhd',         'Petaling Jaya, Selangor','Information Technology'),
('Grab Holdings Malaysia',       'Kuala Lumpur',           'Technology / Logistics'),
('AirAsia Digital',              'Sepang, Selangor',       'Aviation Technology');

-- Students
INSERT INTO students (student_number, full_name, email, programme_id) VALUES
('20CS001', 'Amirul Haziq bin Zulkifli',  'amirul.haziq@student.edu',  1),
('20CS002', 'Nurul Ain binti Hassan',      'nurul.ain@student.edu',      1),
('20IT001', 'Tan Jing Xuan',              'tan.jingxuan@student.edu',   2),
('20IT002', 'Kavitha Selvaraj',           'kavitha.s@student.edu',      2),
('20SE001', 'Muhammad Farhan bin Idris',  'farhan.idris@student.edu',   3),
('20SE002', 'Wong Xin Yi',               'wong.xinyi@student.edu',     3),
('20NET01', 'Mohd Syahril bin Ahmad',     'syahril.ahmad@student.edu',  4),
('20DS001', 'Lee Kai Sheng',             'lee.kaisheng@student.edu',   5),
('20CS003', 'Sarina binti Mahmud',        'sarina.mahmud@student.edu',  1),
('20IT003', 'Raj Kumar a/l Suppiah',      'raj.kumar@student.edu',      2);

-- Internships
INSERT INTO internships (student_id, company_id, assessor_id, start_date, end_date, academic_year, status) VALUES
(1,  1, 2, '2025-06-01', '2025-08-31', '2024/2025', 'completed'),
(2,  2, 2, '2025-06-01', '2025-08-31', '2024/2025', 'completed'),
(3,  3, 3, '2025-06-01', '2025-08-31', '2024/2025', 'completed'),
(4,  4, 3, '2025-06-01', '2025-08-31', '2024/2025', 'ongoing'),
(5,  5, 4, '2025-06-01', '2025-08-31', '2024/2025', 'completed'),
(6,  6, 4, '2025-06-01', '2025-08-31', '2024/2025', 'completed'),
(7,  7, 5, '2025-06-01', '2025-08-31', '2024/2025', 'ongoing'),
(8,  8, 5, '2025-06-01', '2025-08-31', '2024/2025', 'completed'),
(9,  1, 2, '2025-06-01', '2025-08-31', '2024/2025', 'completed'),
(10, 2, 3, '2025-06-01', '2025-08-31', '2024/2025', 'ongoing');

-- Assessments & Scores for completed internships
-- Internship 1 (student 1, assessor 2)
INSERT INTO assessments (internship_id, assessor_id, overall_comment, submitted_at) VALUES
(1, 2, 'Excellent performance overall. Shows strong initiative and professional attitude.', '2025-09-05 10:00:00');
SET @aid = LAST_INSERT_ID();
INSERT INTO assessment_scores (assessment_id, criteria_id, score, comment) VALUES
(@aid,1,88,'Completed all assigned tasks ahead of schedule.'),
(@aid,2,90,'Strictly adhered to all HSE protocols.'),
(@aid,3,85,'Applied theoretical knowledge effectively.'),
(@aid,4,78,'Report was well-structured with minor formatting issues.'),
(@aid,5,80,'Clear and professional writing.'),
(@aid,6,92,'Participated in additional training sessions voluntarily.'),
(@aid,7,86,'Managed project milestones effectively.'),
(@aid,8,89,'Consistently punctual and met all deadlines.');

-- Internship 2 (student 2, assessor 2)
INSERT INTO assessments (internship_id, assessor_id, overall_comment, submitted_at) VALUES
(2, 2, 'Good performance with room for improvement in report writing.', '2025-09-06 11:30:00');
SET @aid = LAST_INSERT_ID();
INSERT INTO assessment_scores (assessment_id, criteria_id, score, comment) VALUES
(@aid,1,75,'Completed tasks satisfactorily.'),
(@aid,2,82,'Good safety awareness.'),
(@aid,3,70,'Needs more application of theoretical concepts.'),
(@aid,4,65,'Report needs more structured approach.'),
(@aid,5,72,'Language mostly clear but some ambiguities.'),
(@aid,6,78,'Participated in most learning activities.'),
(@aid,7,74,'Reasonable project management.'),
(@aid,8,80,'Generally punctual.');

-- Internship 3 (student 3, assessor 3)
INSERT INTO assessments (internship_id, assessor_id, overall_comment, submitted_at) VALUES
(3, 3, 'Outstanding intern. Highly recommended for full-time positions.', '2025-09-04 09:00:00');
SET @aid = LAST_INSERT_ID();
INSERT INTO assessment_scores (assessment_id, criteria_id, score, comment) VALUES
(@aid,1,95,'Exceeded all task expectations.'),
(@aid,2,93,'Perfect HSE compliance.'),
(@aid,3,91,'Excellent application of knowledge.'),
(@aid,4,88,'Very professional report presentation.'),
(@aid,5,90,'Excellent communication skills.'),
(@aid,6,96,'Proactively sought learning opportunities.'),
(@aid,7,94,'Outstanding project planning.'),
(@aid,8,97,'Always on time, highly disciplined.');

-- Internship 5 (student 5, assessor 4)
INSERT INTO assessments (internship_id, assessor_id, overall_comment, submitted_at) VALUES
(5, 4, 'Satisfactory performance. Needs improvement in time management.', '2025-09-07 14:00:00');
SET @aid = LAST_INSERT_ID();
INSERT INTO assessment_scores (assessment_id, criteria_id, score, comment) VALUES
(@aid,1,72,'Tasks completed but required supervision.'),
(@aid,2,78,'Adequate safety compliance.'),
(@aid,3,68,'Needs to bridge theory-practice gap.'),
(@aid,4,70,'Report acceptable but lacks depth.'),
(@aid,5,65,'Language needs improvement.'),
(@aid,6,74,'Average participation in learning activities.'),
(@aid,7,71,'Some project delays observed.'),
(@aid,8,60,'Occasionally late on submissions.');

-- Internship 6 (student 6, assessor 4)
INSERT INTO assessments (internship_id, assessor_id, overall_comment, submitted_at) VALUES
(6, 4, 'Very good intern with strong analytical skills.', '2025-09-08 10:30:00');
SET @aid = LAST_INSERT_ID();
INSERT INTO assessment_scores (assessment_id, criteria_id, score, comment) VALUES
(@aid,1,85,'Proactive and thorough in task completion.'),
(@aid,2,88,'High safety awareness demonstrated.'),
(@aid,3,84,'Good theoretical application.'),
(@aid,4,82,'Well-written technical report.'),
(@aid,5,86,'Clear communication throughout.'),
(@aid,6,88,'Actively engaged in learning activities.'),
(@aid,7,83,'Effective project management.'),
(@aid,8,87,'Reliable time management.');

-- Internship 8 (student 8, assessor 5)
INSERT INTO assessments (internship_id, assessor_id, overall_comment, submitted_at) VALUES
(8, 5, 'Strong technical intern with impressive data analysis skills.', '2025-09-09 09:45:00');
SET @aid = LAST_INSERT_ID();
INSERT INTO assessment_scores (assessment_id, criteria_id, score, comment) VALUES
(@aid,1,90,'Exceptional task delivery.'),
(@aid,2,85,'Good safety practices.'),
(@aid,3,92,'Excellent theory-to-practice mapping.'),
(@aid,4,87,'Well-presented documentation.'),
(@aid,5,88,'Very clear illustrations and language.'),
(@aid,6,91,'Outstanding learning engagement.'),
(@aid,7,89,'Superb project management.'),
(@aid,8,93,'Exemplary time management.');

-- Internship 9 (student 9, assessor 2)
INSERT INTO assessments (internship_id, assessor_id, overall_comment, submitted_at) VALUES
(9, 2, 'Good overall performance with consistent effort.', '2025-09-10 11:00:00');
SET @aid = LAST_INSERT_ID();
INSERT INTO assessment_scores (assessment_id, criteria_id, score, comment) VALUES
(@aid,1,79,'Tasks completed on time.'),
(@aid,2,81,'Safety rules followed.'),
(@aid,3,76,'Reasonable knowledge application.'),
(@aid,4,73,'Report acceptable.'),
(@aid,5,77,'Communication adequate.'),
(@aid,6,80,'Participated in required activities.'),
(@aid,7,78,'Managed workload reasonably.'),
(@aid,8,82,'Time management acceptable.');
