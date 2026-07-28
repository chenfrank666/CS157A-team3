<%@ page import="java.sql.*, javax.naming.*, javax.sql.DataSource" %>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    if (auth_admin_flag != 1) {
        response.sendRedirect("/tomcat-app/gym-management/");
        return;
    }

    String active_page = "add-member";
%>
<!DOCTYPE html>
<html>
<head>
    <title>Add Member - Gym Management System</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <%@ include file="/WEB-INF/includes/navbar.jspf" %>

</body>
</html>
