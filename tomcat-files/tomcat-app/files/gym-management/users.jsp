<%@ page import="java.sql.*, javax.naming.*, javax.sql.DataSource" %>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    if (auth_admin_flag != 1) {
        response.sendRedirect("/tomcat-app/gym-management/");
        return;
    }

    String active_page = "users";
%>
<!DOCTYPE html>
<html>
<head>
    <title>View Users - Gym Management System</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <%@ include file="/WEB-INF/includes/navbar.jspf" %>

    <div class="container">
        <h2>System Users Roster</h2>

        <%
            Connection conn = null;
            PreparedStatement empStmt = null;
            PreparedStatement memStmt = null;
            ResultSet empRs = null;
            ResultSet memRs = null;

            try {
                Context initContext = new InitialContext();
                Context envContext = (Context) initContext.lookup("java:/comp/env");
                DataSource ds = (DataSource) envContext.lookup("jdbc/GymDB");
                conn = ds.getConnection();
        %>

        <!-- Employees Section -->
        <h3>Employees</h3>
        <table class="data-table" border="1" cellpadding="8" cellspacing="0" style="width: 100%; margin-bottom: 30px;">
            <thead style="background-color: #f4f4f4;">
                <tr>
                    <th>ID</th>
                    <th>Name</th>
                    <th>Username</th>
                    <th>Admin</th>
                    <th>Coach</th>
                </tr>
            </thead>
            <tbody>
                <%
                    String empQuery = "SELECT u.user_id, u.first_name, u.last_name, u.user_name, e.coach_flag, e.admin_flag " +
                                      "FROM users u JOIN employees e ON u.user_id = e.user_id WHERE u.user_type = 0";
                    empStmt = conn.prepareStatement(empQuery);
                    empRs = empStmt.executeQuery();

                    while(empRs.next()) {
                %>
                <tr>
                    <td><%= empRs.getInt("user_id") %></td>
                    <td><%= empRs.getString("first_name") %> <%= empRs.getString("last_name") %></td>
                    <td><%= empRs.getString("user_name") %></td>
                    <td><%= empRs.getInt("admin_flag") == 1 ? "Yes" : "No" %></td>
                    <td><%= empRs.getInt("coach_flag") == 1 ? "Yes" : "No" %></td>
                </tr>
                <%  } %>
            </tbody>
        </table>

        <!-- Members Section -->
        <h3>Members</h3>
        <table class="data-table" border="1" cellpadding="8" cellspacing="0" style="width: 100%;">
            <thead style="background-color: #f4f4f4;">
                <tr>
                    <th>ID</th>
                    <th>Name</th>
                    <th>Username</th>
                    <th>Goals</th>
                    <th>Health Notes</th>
                    <th>Status</th>
                </tr>
            </thead>
            <tbody>
                <%
                    String memQuery = "SELECT u.user_id, u.first_name, u.last_name, u.user_name, m.goals, m.health_notes, m.active_flag " +
                                      "FROM users u JOIN members m ON u.user_id = m.user_id WHERE u.user_type = 1";
                    memStmt = conn.prepareStatement(memQuery);
                    memRs = memStmt.executeQuery();

                    while(memRs.next()) {
                %>
                <tr>
                    <td><%= memRs.getInt("user_id") %></td>
                    <td><%= memRs.getString("first_name") %> <%= memRs.getString("last_name") %></td>
                    <td><%= memRs.getString("user_name") %></td>
                    <td><%= memRs.getString("goals") != null ? memRs.getString("goals") : "None" %></td>
                    <td><%= memRs.getString("health_notes") != null ? memRs.getString("health_notes") : "None" %></td>
                    <td><%= memRs.getInt("active_flag") == 1 ? "Active" : "Inactive" %></td>
                </tr>
                <%  } %>
            </tbody>
        </table>

        <%
            } catch (Exception e) {
                out.println("<p style='color: red;'>Error loading users: " + e.getMessage() + "</p>");
                e.printStackTrace();
            } finally {
                if (empRs != null) try { empRs.close(); } catch (SQLException ignore) {}
                if (memRs != null) try { memRs.close(); } catch (SQLException ignore) {}
                if (empStmt != null) try { empStmt.close(); } catch (SQLException ignore) {}
                if (memStmt != null) try { memStmt.close(); } catch (SQLException ignore) {}
                if (conn != null) try { conn.close(); } catch (SQLException ignore) {}
            }
        %>

    </div>
</body>
</html>