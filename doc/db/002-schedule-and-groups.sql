-- Migrate the "Stankovich" dev database to match the final data model from
-- doc/ProjectDataModel-andDBDesignReport, adding the tables needed for the
-- "View schedule" and "Managing groups" (join/leave) functional requirements.
--
-- Run once against a database that still has the original 3-table schema
-- (users/employees/members only, cookie on employees/members). Back up first
-- (e.g. `mysqldump Stankovich > backup.sql`) -- steps 1-2 drop columns.
--
-- The seed data in section 5 assumes the two starter accounts from
-- deployment.md (user_id 1 = employee "emp1", user_id 2 = member "mem1").
-- Adjust those ids if your local data differs.

-- 1. Move general profile + auth-cookie fields onto the "users" superclass,
--    per the report's ERD (they currently live on employees/members).
ALTER TABLE users
    ADD COLUMN first_name VARCHAR(45) DEFAULT NULL,
    ADD COLUMN last_name VARCHAR(45) DEFAULT NULL,
    ADD COLUMN start_date DATE DEFAULT NULL,
    ADD COLUMN end_date DATE DEFAULT NULL,
    ADD COLUMN cookie_value VARCHAR(45) DEFAULT NULL,
    ADD COLUMN cookie_expiration_time DATETIME DEFAULT NULL,
    ADD UNIQUE KEY user_cookie_value_UNIQUE (cookie_value);

UPDATE users u JOIN employees e ON e.user_id = u.user_id
    SET u.first_name = e.first_name,
        u.last_name = e.last_name,
        u.cookie_value = NULLIF(e.user_cookie, '');

UPDATE users u JOIN members m ON m.user_id = u.user_id
    SET u.first_name = m.first_name,
        u.last_name = m.last_name,
        u.cookie_value = NULLIF(m.user_cookie, '');

-- 2. Add the subclass-specific attributes from the report, then drop the
--    now-duplicated columns that moved to "users".
ALTER TABLE employees
    ADD COLUMN coach_flag TINYINT NOT NULL DEFAULT 0,
    ADD COLUMN admin_flag TINYINT NOT NULL DEFAULT 0;

ALTER TABLE members
    ADD COLUMN goals VARCHAR(255) DEFAULT NULL,
    ADD COLUMN health_notes VARCHAR(255) DEFAULT NULL,
    ADD COLUMN active_flag TINYINT NOT NULL DEFAULT 1;

ALTER TABLE employees DROP KEY user_cookie_UNIQUE;
ALTER TABLE employees DROP COLUMN first_name, DROP COLUMN last_name, DROP COLUMN user_cookie;

ALTER TABLE members DROP KEY user_cookie_UNIQUE;
ALTER TABLE members DROP COLUMN first_name, DROP COLUMN last_name, DROP COLUMN user_cookie;

-- 3. New tables for scheduling and group membership.
CREATE TABLE sports (
    sport_id INT NOT NULL AUTO_INCREMENT,
    sport_name VARCHAR(45) NOT NULL,
    PRIMARY KEY (sport_id)
);

CREATE TABLE locations (
    location_id INT NOT NULL AUTO_INCREMENT,
    location_name VARCHAR(45) NOT NULL,
    PRIMARY KEY (location_id)
);

CREATE TABLE `groups` (
    group_id INT NOT NULL AUTO_INCREMENT,
    active_flag TINYINT NOT NULL DEFAULT 1,
    start_date DATE DEFAULT NULL,
    end_date DATE DEFAULT NULL,
    duration INT DEFAULT NULL,
    Monday_time TIME DEFAULT NULL,
    Tuesday_time TIME DEFAULT NULL,
    Wednesday_time TIME DEFAULT NULL,
    Thursday_time TIME DEFAULT NULL,
    Friday_time TIME DEFAULT NULL,
    Saturday_time TIME DEFAULT NULL,
    Sunday_time TIME DEFAULT NULL,
    PRIMARY KEY (group_id)
);

CREATE TABLE sport_groups (
    group_id INT NOT NULL,
    sport_id INT NOT NULL,
    PRIMARY KEY (group_id),
    CONSTRAINT fk_sport_groups_group FOREIGN KEY (group_id) REFERENCES `groups` (group_id),
    CONSTRAINT fk_sport_groups_sport FOREIGN KEY (sport_id) REFERENCES sports (sport_id)
);

CREATE TABLE location_groups (
    group_id INT NOT NULL,
    location_id INT NOT NULL,
    PRIMARY KEY (group_id, location_id),
    CONSTRAINT fk_location_groups_group FOREIGN KEY (group_id) REFERENCES `groups` (group_id),
    CONSTRAINT fk_location_groups_location FOREIGN KEY (location_id) REFERENCES locations (location_id)
);

CREATE TABLE class_schedule (
    group_id INT NOT NULL,
    `date` DATE NOT NULL,
    `time` TIME NOT NULL,
    PRIMARY KEY (group_id, `date`),
    CONSTRAINT fk_class_schedule_group FOREIGN KEY (group_id) REFERENCES `groups` (group_id)
);

CREATE TABLE class_coach (
    group_id INT NOT NULL,
    `date` DATE NOT NULL,
    user_id INT NOT NULL,
    PRIMARY KEY (group_id, `date`),
    CONSTRAINT fk_class_coach_schedule FOREIGN KEY (group_id, `date`) REFERENCES class_schedule (group_id, `date`),
    CONSTRAINT fk_class_coach_employee FOREIGN KEY (user_id) REFERENCES employees (user_id)
);

CREATE TABLE cancellations (
    group_id INT NOT NULL,
    `date` DATE NOT NULL,
    reason VARCHAR(255) DEFAULT NULL,
    PRIMARY KEY (group_id, `date`),
    CONSTRAINT fk_cancellations_group FOREIGN KEY (group_id) REFERENCES `groups` (group_id)
);

CREATE TABLE group_membership (
    group_id INT NOT NULL,
    member_id INT NOT NULL,
    PRIMARY KEY (group_id, member_id),
    CONSTRAINT fk_group_membership_group FOREIGN KEY (group_id) REFERENCES `groups` (group_id),
    CONSTRAINT fk_group_membership_member FOREIGN KEY (member_id) REFERENCES members (user_id)
);

-- 4. Give the existing test employee (emp1 / Alexandra Stankovich) both the
--    coach and admin flags, so both roles are exercisable right away.
UPDATE employees SET coach_flag = 1, admin_flag = 1 WHERE user_id = 1;

-- 5. Minimal seed data so the new pages have something real to display.
INSERT INTO sports (sport_name) VALUES ('Yoga'), ('Boxing');
INSERT INTO locations (location_name) VALUES ('Studio A'), ('Boxing Ring');

INSERT INTO `groups` (active_flag, start_date, duration, Monday_time, Wednesday_time, Friday_time)
    VALUES (1, CURDATE(), 60, '09:00:00', '09:00:00', '09:00:00');
SET @yoga_group := LAST_INSERT_ID();

INSERT INTO `groups` (active_flag, start_date, duration, Tuesday_time, Thursday_time)
    VALUES (1, CURDATE(), 45, '18:00:00', '18:00:00');
SET @boxing_group := LAST_INSERT_ID();

INSERT INTO sport_groups (group_id, sport_id)
    VALUES (@yoga_group, (SELECT sport_id FROM sports WHERE sport_name = 'Yoga'));
INSERT INTO sport_groups (group_id, sport_id)
    VALUES (@boxing_group, (SELECT sport_id FROM sports WHERE sport_name = 'Boxing'));

INSERT INTO location_groups (group_id, location_id)
    VALUES (@yoga_group, (SELECT location_id FROM locations WHERE location_name = 'Studio A'));
-- Boxing group is deliberately left without a location to exercise the "TBD" UI.

-- Mon/Wed/Fri sessions over the next two weeks for the Yoga group.
INSERT INTO class_schedule (group_id, `date`, `time`) VALUES
    (@yoga_group, DATE_ADD(CURDATE(), INTERVAL 1 DAY), '09:00:00'),
    (@yoga_group, DATE_ADD(CURDATE(), INTERVAL 3 DAY), '09:00:00'),
    (@yoga_group, DATE_ADD(CURDATE(), INTERVAL 5 DAY), '09:00:00'),
    (@yoga_group, DATE_ADD(CURDATE(), INTERVAL 8 DAY), '09:00:00'),
    (@yoga_group, DATE_ADD(CURDATE(), INTERVAL 10 DAY), '09:00:00'),
    (@yoga_group, DATE_ADD(CURDATE(), INTERVAL 12 DAY), '09:00:00');

-- Tue/Thu sessions over the next two weeks for the Boxing group (no coach
-- assigned yet, to exercise the "coach TBD" UI).
INSERT INTO class_schedule (group_id, `date`, `time`) VALUES
    (@boxing_group, DATE_ADD(CURDATE(), INTERVAL 2 DAY), '18:00:00'),
    (@boxing_group, DATE_ADD(CURDATE(), INTERVAL 4 DAY), '18:00:00'),
    (@boxing_group, DATE_ADD(CURDATE(), INTERVAL 9 DAY), '18:00:00'),
    (@boxing_group, DATE_ADD(CURDATE(), INTERVAL 11 DAY), '18:00:00');

INSERT INTO class_coach (group_id, `date`, user_id)
    SELECT group_id, `date`, 1 FROM class_schedule WHERE group_id = @yoga_group;

-- One Yoga session is already cancelled, to exercise the cancelled-row UI.
INSERT INTO cancellations (group_id, `date`, reason)
    SELECT group_id, `date`, 'Studio maintenance'
    FROM class_schedule
    WHERE group_id = @yoga_group
    ORDER BY `date` DESC LIMIT 1;

-- The existing test member (mem1 / Kristy Chan) is already enrolled in Yoga,
-- so Groups shows both the "Leave" and "Join" paths on first load.
INSERT INTO group_membership (group_id, member_id) VALUES (@yoga_group, 2);
