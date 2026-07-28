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

Database "Stankovich" should be accessible to "Stankovich" database user and contain tables matching the data model in `ProjectDataModel-andDBDesignReport`: `users`, `employees`, `members`, `sports`, `locations`, `` `groups` ``, `sport_groups`, `location_groups`, `class_schedule`, `class_coach`, `cancellations`, and `group_membership`.

Notably, authentication cookie fields (`cookie_value`, `cookie_expiration_time`) live on `users` along with `first_name`/`last_name`, not on `employees`/`members` as in an earlier draft of this schema — `employees` only carries `coach_flag`/`admin_flag`, and `members` only carries `goals`/`health_notes`/`active_flag`.

A database still on the earlier draft schema can be brought up to date with `doc/db/002-schedule-and-groups.sql`.

After configuration Tomcat server should be restarted.

Future releases will allow more configuration of paths, URLs and databases.
