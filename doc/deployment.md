# Deployment

This is a work in progress. Current configuration is intended for development.

Gym Management System has fixed URL path
`/tomcat-app/gym-management/` and files location `/home/tomcat-files/tomcat-app/files`
MySQL database name is "Stankovich" on `localhost`, database user is also "Stankovich".

Deployment involves installing files under `/home/tomcat-files/tomcat-app/files` and configuring Apache Tomcat application in Tomcat Web Application Manager with the following parameters:

Context Path: `/tomcat-app`  
XML Configuration file path: `/home/tomcat-files/tomcat-app/config/context.xml`

Additionally, `catalina.properties` file (usually `/etc/tomcat10/catalina.properties` should contain the following:

```
gym.db.password=mypassword
```
where `mypassword` is the password for database "Stankovich" on `localhost`.

File `mysql-connector-j-9.7.0.jar` from MySQL Connector/J package (originally usually in `/usr/share/java/mysql-connector-j-9.7.0.jar`) should be copied into `/home/tomcat-files/tomcat-app/files/WEB-INF/lib/mysql-connector-j-9.7.0.jar`.

All files under `/home/tomcat-files/tomcat-app/files` must be readable for Tomcat server user.

Database "Stankovich" should be accessible to "Stankovich" database user and contain tables created with the following statements:
```
CREATE TABLE `users` (
  `user_name` varchar(45) NOT NULL,
  `user_password` varchar(45) NOT NULL,
  `user_id` int NOT NULL,
  `user_type` varchar(45) NOT NULL,
  PRIMARY KEY (`user_name`),
  UNIQUE KEY `user_id_UNIQUE` (`user_id`)
);
```
```
CREATE TABLE `employees` (
  `user_id` int NOT NULL,
  `first_name` varchar(45) DEFAULT NULL,
  `last_name` varchar(45) DEFAULT NULL,
  `user_cookie` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `user_cookie_UNIQUE` (`user_cookie`)
);
```
```
CREATE TABLE `members` (
  `user_id` int NOT NULL,
  `first_name` varchar(45) DEFAULT NULL,
  `last_name` varchar(45) DEFAULT NULL,
  `user_cookie` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `user_cookie_UNIQUE` (`user_cookie`)
);
```
After configuration Tomcat server should be restarted.

Database tables format is preliminary and will be changed to provide functionality of this application.

Future releases will allow more configuration of paths, URLs and databases.
