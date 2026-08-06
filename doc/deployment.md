# Deployment

This is a work in progress. Current configuration is intended for development.

Gym Management System has fixed URL path
`/tomcat-app/gym-management/` and files location `/home/tomcat-files/tomcat-app/files`
The MySQL database runs on `localhost` under whatever name/user you configure in `context.xml`
(e.g. `gym_management` with a dedicated `gym_app` database user)

Deployment involves installing files under `/home/tomcat-files/tomcat-app/files` and configuring Apache Tomcat application in Tomcat Web Application Manager with the following parameters:

Context Path: `/tomcat-app`  
XML Configuration file path: `/home/tomcat-files/tomcat-app/config/context.xml`

Additionally, `catalina.properties` file (usually `/etc/tomcat10/catalina.properties` should contain the following:

```
gym.db.password=mypassword
```
where `mypassword` is the password for your database user on `localhost`.

File `mysql-connector-j-9.7.0.jar` from MySQL Connector/J package (originally usually in `/usr/share/java/mysql-connector-j-9.7.0.jar`) should be copied into `/home/tomcat-files/tomcat-app/files/WEB-INF/lib/mysql-connector-j-9.7.0.jar`.

All files under `/home/tomcat-files/tomcat-app/files` must be readable for Tomcat server user.

The database should be accessible to the database user configured in `context.xml` and contain tables matching the data model in `ProjectDataModel-andDBDesignReport`: `users`, `employees`, `members`, `sports`, `locations`, `` `groups` ``, `sport_groups`, `location_groups`, `class_schedule`, `class_coach`, `class_group`, `cancellations`, `cancel_group`, `class_attendance`, `group_membership`, `requests`, `request_employee`, and `request_group`.

Up-to-date schema (with seed data) is `GymTables_Updated_On_Augest2.sql` at the repo root; load it fresh into your database rather than trying to patch an older copy.

After configuration Tomcat server should be restarted.

Future releases will allow more configuration of paths, URLs and databases.

