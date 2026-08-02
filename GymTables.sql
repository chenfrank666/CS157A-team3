DROP TABLE IF EXISTS `location_groups`;
DROP TABLE IF EXISTS `sport_groups`;
DROP TABLE IF EXISTS `request_group`;
DROP TABLE IF EXISTS `request_employee`;
DROP TABLE IF EXISTS `cancel_group`;
DROP TABLE IF EXISTS `class_group`;
DROP TABLE IF EXISTS `class_coach`;
DROP TABLE IF EXISTS `class_attendance`;
DROP TABLE IF EXISTS `group_membership`;

DROP TABLE IF EXISTS `cancellations`;
DROP TABLE IF EXISTS `class_schedule`;
DROP TABLE IF EXISTS `requests`;
DROP TABLE IF EXISTS `locations`;
DROP TABLE IF EXISTS `sports`;
DROP TABLE IF EXISTS `groups`;
DROP TABLE IF EXISTS `members`;
DROP TABLE IF EXISTS `employees`;
DROP TABLE IF EXISTS `users`;


CREATE TABLE `users` (
  `user_id` int NOT NULL,
  `user_name` varchar(45) NOT NULL,
  `user_password` varchar(45) NOT NULL,
  `user_type` tinyint NOT NULL COMMENT '0=Employee, 1=Member',
  `first_name` varchar(45) DEFAULT NULL,
  `last_name` varchar(45) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `cookie_value` varchar(45) DEFAULT NULL,
  `cookie_expiration_time` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `user_name_UNIQUE` (`user_name`)
);

INSERT INTO `users` (`user_id`, `user_name`, `user_password`, `user_type`, `first_name`, `last_name`, `start_date`) VALUES
  (1, 'cramirez', 'tiger', 0, 'Christopher', 'Ramirez', '2026-01-25'),
  (2, 'sking', 'lion', 0, 'Shelly', 'King', '2026-02-01'),
  (3, 'thughes', 'carrot', 0, 'Tiffany', 'Hughes', '2026-02-15'),
  (4, 'hbarber', 'apple', 0, 'Holly', 'Barber', '2026-03-01'),
  (5, 'telliott', 'lemon', 0, 'Theresa', 'Elliott', '2026-03-15'),
  (6, 'jwarren', 'tomato', 0, 'Jacob', 'Warren', '2026-04-15'),
  (7, 'tramirez', 'rabbit', 0, 'Tammie', 'Ramirez', '2026-05-01'),
  (8, 'ajohnson', 'wolf', 0, 'Allison', 'Johnson', '2026-05-15'),
  (9, 'mbell', 'peach', 0, 'Melody', 'Bell', '2026-06-01'),
  (10, 'nadams', 'banana', 0, 'Nancy', 'Adams', '2026-06-15'),
  (11, 'jallen', 'orange', 1, 'Jonathan', 'Allen', '2026-07-01'),
  (12, 'abutler', 'pinapple', 1, 'Ashley', 'Butler', '2026-07-05'),
  (13, 'nstewart', 'cucumber', 1, 'Nicholas', 'Stewart', '2026-06-10'),
  (14, 'jpatterson', 'pepper', 1, 'Juan', 'Patterson', '2026-05-01'),
  (15, 'tmiller', 'deer', 1, 'Taylor', 'Miller', '2026-04-15'),
  (16, 'aberg', 'kangaroo', 1, 'Allison', 'Berg', '2026-04-25'),
  (17, 'kanderson', 'kitten', 1, 'Kevin', 'Anderson', '2026-04-08'),
  (18, 'dchang', 'iguana', 1, 'Douglas', 'Chang', '2026-03-20'),
  (19, 'sthomas', 'lizard', 1, 'Stephen', 'Thomas', '2026-03-01'),
  (20, 'lortiz', 'snail', 1, 'Luis', 'Ortiz', '2024-03-20');

CREATE TABLE `employees` (
  `user_id` int NOT NULL,
  `coach_flag` tinyint DEFAULT 0,
  `admin_flag` tinyint DEFAULT 0,
  PRIMARY KEY (`user_id`),
  FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
);

INSERT INTO `employees` VALUES
  (1, 0, 1), (2, 1, 0), (3, 1, 0), (4, 1, 0), (5, 0, 1),
  (6, 1, 0), (7, 0, 0), (8, 0, 0), (9, 0, 0), (10, 0, 0);

CREATE TABLE `members` (
  `user_id` int NOT NULL,
  `goals` varchar(4096) DEFAULT NULL,
  `health_notes` varchar(4096) DEFAULT NULL,
  `active_flag` tinyint DEFAULT 1,
  PRIMARY KEY (`user_id`),
  FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE
);

INSERT INTO `members` VALUES
  (11, 'improve physical fitness', 'myopia', 1),
  (12, 'prepare for military service', 'healthy', 1),
  (13, 'strengthen muscles', 'recent fracture of the left arm', 1),
  (14, 'build abs', 'healthy', 1),
  (15, 'improve physical fitness', 'flat feet', 1),
  (16, 'get into a sport science program', 'healthy', 1),
  (17, 'lose weight', 'hypertension', 1),
  (18, 'earn the title of Master of Sport', 'healthy', 1),
  (19, 'impove physical fitness', 'valgus deformity of the feet', 1),
  (20, 'build muscle', 'healthy', 0);

CREATE TABLE `groups` (
  `group_id` int NOT NULL AUTO_INCREMENT,
  `active_flag` tinyint NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date DEFAULT NULL,
  `duration` int NOT NULL COMMENT 'Minutes',
  `Monday_time` time DEFAULT NULL,
  `Tuesday_time` time DEFAULT NULL,
  `Wednesday_time` time DEFAULT NULL,
  `Thursday_time` time DEFAULT NULL,
  `Friday_time` time DEFAULT NULL,
  `Saturday_time` time DEFAULT NULL,
  `Sunday_time` time DEFAULT NULL,
  PRIMARY KEY (`group_id`)
);

INSERT INTO `groups` (`active_flag`, `start_date`, `end_date`, `duration`, `Monday_time`, `Tuesday_time`, `Wednesday_time`, `Thursday_time`, `Friday_time`, `Saturday_time`, `Sunday_time`) VALUES
  (1, '2026-08-01', NULL, 60, '09:00:00', NULL, '09:00:00', NULL, '09:00:00', NULL, NULL),
  (1, '2026-08-01', NULL, 45, NULL, '10:00:00', NULL, '10:00:00', NULL, '10:00:00', NULL),
  (1, '2026-08-01', '2026-12-01', 60, '17:00:00', '17:00:00', '17:00:00', '17:00:00', '17:00:00', NULL, NULL),
  (0, '2026-01-01', '2026-06-01', 90, NULL, NULL, NULL, NULL, NULL, '14:00:00', '14:00:00'),
  (1, '2026-08-01', NULL, 45, '06:00:00', '06:00:00', '06:00:00', NULL, NULL, NULL, NULL),
  (1, '2026-08-01', NULL, 45, NULL, NULL, NULL, '18:30:00', NULL, '10:00:00', NULL),
  (1, '2026-08-01', NULL, 60, '12:00:00', '12:00:00', '12:00:00', '12:00:00', '12:00:00', NULL, NULL),
  (1, '2026-08-01', NULL, 60, NULL, '19:00:00', NULL, '19:00:00', NULL, NULL, NULL),
  (1, '2026-08-01', NULL, 90, '19:30:00', NULL, '19:30:00', NULL, '19:30:00', NULL, NULL),
  (1, '2026-08-01', NULL, 120, NULL, NULL, NULL, NULL, NULL, '08:00:00', '08:00:00');

CREATE TABLE `sports` (
  `sport_id` int NOT NULL AUTO_INCREMENT,
  `sport_name` varchar(100) NOT NULL,
  PRIMARY KEY (`sport_id`)
);

INSERT INTO `sports` (`sport_name`) VALUES
  ('Weightlifting'), ('Yoga'), ('Pilates'), ('Boxing'), ('Swimming'),
  ('Cycling'), ('CrossFit'), ('Zumba'), ('Martial Arts'), ('Powerlifting');

CREATE TABLE `locations` (
  `location_id` int NOT NULL AUTO_INCREMENT,
  `location_name` varchar(100) NOT NULL,
  PRIMARY KEY (`location_id`)
);

INSERT INTO `locations` (`location_name`) VALUES
  ('Main Weight Room'), ('Studio A'), ('Studio B'), ('Boxing Ring'), ('Lap Pool'),
  ('Spin Studio'), ('CrossFit Turf'), ('Outdoor Area'), ('Cardio Zone'), ('Recovery Room');

CREATE TABLE `requests` (
  `request_id` int NOT NULL AUTO_INCREMENT,
  `request_type` int NOT NULL COMMENT '0=Cancel, 1=Join, 2=Leave',
  `request_text` text,
  `request_date` date NOT NULL,
  `target_date` date NOT NULL,
  PRIMARY KEY (`request_id`)
);

INSERT INTO `requests` (`request_type`, `request_text`, `request_date`, `target_date`) VALUES
  (0, 'Sick leave, need to cancel', '2026-07-01', '2026-07-10'),
  (1, 'Would like to co-coach this class', '2026-06-25', '2026-07-01'),
  (2, 'Schedule conflict, need to leave group', '2026-07-02', '2026-08-01'),
  (1, 'Available to take over', '2026-07-03', '2026-07-15'),
  (0, 'Facility issue', '2026-07-04', '2026-07-11'),
  (1, 'Interested in taking this shift', '2026-07-05', '2026-07-20'),
  (2, 'Moving to a different location', '2026-06-15', '2026-07-31'),
  (1, 'I can cover this class', '2026-07-06', '2026-07-14'),
  (0, 'Personal emergency', '2026-07-05', '2026-07-08'),
  (1, 'I will cover the sick leave', '2026-07-02', '2026-07-10');

CREATE TABLE `class_schedule` (
  `group_id` int NOT NULL,
  `date` date NOT NULL,
  `time` time NOT NULL,
  PRIMARY KEY (`group_id`, `date`)
);

INSERT INTO `class_schedule` VALUES
  (1, '2026-08-03', '09:00:00'), (2, '2026-08-04', '10:00:00'), (3, '2026-08-05', '17:00:00'),
  (4, '2026-08-08', '14:00:00'), (5, '2026-08-03', '06:00:00'), (6, '2026-08-06', '18:30:00'),
  (7, '2026-08-04', '12:00:00'), (8, '2026-08-04', '19:00:00'), (9, '2026-08-05', '19:30:00'),
  (10, '2026-08-08', '08:00:00');

CREATE TABLE `cancellations` (
  `group_id` int NOT NULL,
  `date` date NOT NULL,
  `reason` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`group_id`, `date`)
);

INSERT INTO `cancellations` VALUES
  (1, '2026-08-10', 'Coach sick'), (2, '2026-08-11', 'Holiday closure'),
  (3, '2026-08-12', 'Facility repairs'), (4, '2026-08-15', 'Pool maintenance'),
  (5, '2026-08-17', 'Emergency'), (6, '2026-08-20', 'Low attendance'),
  (7, '2026-08-21', 'Severe weather'), (8, '2026-08-25', 'Instructor unavailable'),
  (9, '2026-08-26', 'Double booked room'), (10, '2026-08-29', 'Equipment maintenance');



CREATE TABLE `group_membership` (
  `group_id` int NOT NULL,
  `member_id` int NOT NULL,
  PRIMARY KEY (`group_id`, `member_id`),
  FOREIGN KEY (`group_id`) REFERENCES `groups` (`group_id`) ON DELETE CASCADE,
  FOREIGN KEY (`member_id`) REFERENCES `members` (`user_id`) ON DELETE CASCADE
);
INSERT INTO `group_membership` VALUES (1, 11), (1, 12), (2, 13), (2, 14), (3, 15), (4, 16), (5, 17), (6, 18), (7, 19), (8, 20);

CREATE TABLE `class_attendance` (
  `group_id` int NOT NULL,
  `coach_id` int NOT NULL,
  `member_id` int NOT NULL,
  `date` date NOT NULL,
  PRIMARY KEY (`group_id`, `member_id`, `date`),
  FOREIGN KEY (`group_id`, `date`) REFERENCES `class_schedule` (`group_id`, `date`) ON DELETE CASCADE,
  FOREIGN KEY (`coach_id`) REFERENCES `employees` (`user_id`) ON DELETE CASCADE,
  FOREIGN KEY (`member_id`) REFERENCES `members` (`user_id`) ON DELETE CASCADE
);
INSERT INTO `class_attendance` VALUES 
  (1, 2, 11, '2026-08-03'), (1, 2, 12, '2026-08-03'), (2, 3, 13, '2026-08-04'), (2, 3, 14, '2026-08-04'),
  (3, 4, 15, '2026-08-05'), (4, 6, 16, '2026-08-08'), (5, 2, 17, '2026-08-03'), (6, 3, 18, '2026-08-06'),
  (7, 4, 19, '2026-08-04'), (8, 6, 20, '2026-08-04');

CREATE TABLE `class_coach` (
  `group_id` int NOT NULL,
  `date` date NOT NULL,
  `user_id` int NOT NULL COMMENT 'Employee/Coach ID',
  PRIMARY KEY (`group_id`, `date`, `user_id`),
  FOREIGN KEY (`group_id`, `date`) REFERENCES `class_schedule` (`group_id`, `date`) ON DELETE CASCADE,
  FOREIGN KEY (`user_id`) REFERENCES `employees` (`user_id`) ON DELETE CASCADE
);
INSERT INTO `class_coach` VALUES (1, '2026-08-03', 2), (2, '2026-08-04', 3), (3, '2026-08-05', 4), (4, '2026-08-08', 6), (5, '2026-08-03', 2), (6, '2026-08-06', 3), (7, '2026-08-04', 4), (8, '2026-08-04', 6), (9, '2026-08-05', 2), (10, '2026-08-08', 3);

CREATE TABLE `class_group` (
  `group_id` int NOT NULL,
  `date` date NOT NULL,
  PRIMARY KEY (`group_id`, `date`),
  FOREIGN KEY (`group_id`) REFERENCES `groups` (`group_id`) ON DELETE CASCADE,
  FOREIGN KEY (`group_id`, `date`) REFERENCES `class_schedule` (`group_id`, `date`) ON DELETE CASCADE
);
INSERT INTO `class_group` VALUES (1, '2026-08-03'), (2, '2026-08-04'), (3, '2026-08-05'), (4, '2026-08-08'), (5, '2026-08-03'), (6, '2026-08-06'), (7, '2026-08-04'), (8, '2026-08-04'), (9, '2026-08-05'), (10, '2026-08-08');

CREATE TABLE `cancel_group` (
  `group_id` int NOT NULL,
  `date` date NOT NULL,
  PRIMARY KEY (`group_id`, `date`),
  FOREIGN KEY (`group_id`) REFERENCES `groups` (`group_id`) ON DELETE CASCADE,
  FOREIGN KEY (`group_id`, `date`) REFERENCES `cancellations` (`group_id`, `date`) ON DELETE CASCADE
);
INSERT INTO `cancel_group` VALUES (1, '2026-08-10'), (2, '2026-08-11'), (3, '2026-08-12'), (4, '2026-08-15'), (5, '2026-08-17'), (6, '2026-08-20'), (7, '2026-08-21'), (8, '2026-08-25'), (9, '2026-08-26'), (10, '2026-08-29');

CREATE TABLE `request_employee` (
  `request_id` int NOT NULL,
  `user_id` int NOT NULL,
  PRIMARY KEY (`request_id`, `user_id`),
  FOREIGN KEY (`request_id`) REFERENCES `requests` (`request_id`) ON DELETE CASCADE,
  FOREIGN KEY (`user_id`) REFERENCES `employees` (`user_id`) ON DELETE CASCADE
);
INSERT INTO `request_employee` VALUES (1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8), (9, 9), (10, 10);

CREATE TABLE `request_group` (
  `request_id` int NOT NULL,
  `group_id` int NOT NULL,
  PRIMARY KEY (`request_id`, `group_id`),
  FOREIGN KEY (`request_id`) REFERENCES `requests` (`request_id`) ON DELETE CASCADE,
  FOREIGN KEY (`group_id`) REFERENCES `groups` (`group_id`) ON DELETE CASCADE
);
INSERT INTO `request_group` VALUES (1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8), (9, 9), (10, 10);

CREATE TABLE `sport_groups` (
  `group_id` int NOT NULL,
  `sport_id` int NOT NULL,
  PRIMARY KEY (`group_id`, `sport_id`),
  FOREIGN KEY (`group_id`) REFERENCES `groups` (`group_id`) ON DELETE CASCADE,
  FOREIGN KEY (`sport_id`) REFERENCES `sports` (`sport_id`) ON DELETE CASCADE
);
INSERT INTO `sport_groups` VALUES (1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8), (9, 9), (10, 10);

CREATE TABLE `location_groups` (
  `group_id` int NOT NULL,
  `location_id` int NOT NULL,
  PRIMARY KEY (`group_id`, `location_id`),
  FOREIGN KEY (`group_id`) REFERENCES `groups` (`group_id`) ON DELETE CASCADE,
  FOREIGN KEY (`location_id`) REFERENCES `locations` (`location_id`) ON DELETE CASCADE
);
INSERT INTO `location_groups` VALUES (1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8), (9, 2), (10, 1);