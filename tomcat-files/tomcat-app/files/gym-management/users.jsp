<%@ page import="java.sql.*, javax.naming.*, javax.sql.DataSource" %>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    if ((auth_admin_flag != 1) || (con == null)) {
        response.sendRedirect("/tomcat-app/gym-management/");
	if (con != null) try { con.close(); } catch (SQLException ignore) {}
        return;
    }

    String active_page = "users";

    // --- UNIFIED DEACTIVATE / ACTIVATE LOGIC ---
    if (request.getMethod().equals("POST")) {
        try {
            int target_user_id = Integer.parseInt(request.getParameter("target_user_id"));
            String action = request.getParameter("user_action");

            int new_flag = "activate".equals(action) ? 1 : 0;
            
            // Updates active_flag directly on the users superclass table
            String update_sql = "UPDATE users SET active_flag = ? WHERE user_id = ?";
            PreparedStatement update_stmt = con.prepareStatement(update_sql);
            update_stmt.setInt(1, new_flag);
            update_stmt.setInt(2, target_user_id);
            update_stmt.executeUpdate();
            update_stmt.close();
        } catch (Exception e) {}
        response.sendRedirect("users.jsp");
	try { con.close(); } catch (SQLException ignore) {}
        return;
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>View Users - Gym Management System</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <%@ include file="/WEB-INF/includes/navbar.jspf" %>

    <main class="container">
        <!-- SEARCH BAR CARD -->
        <div class="card">
            <div class="card-header" style="margin-bottom: 0;">
                <div style="width: 100%;">
                    <h1>System Users Roster</h1>
                    <p class="subtitle">Search and filter active/inactive employees and members registered in the system.</p>
                    <div style="margin-top: 16px;">
                        <input type="text" id="userSearchInput" onkeyup="filterUsers()" placeholder="Search by name, username, ID, or goals..." style="width: 100%; padding: 12px; font-size: 0.95rem; border: 1px solid var(--color-border); border-radius: 8px;">
                    </div>
                </div>
            </div>
        </div>

        <%
            PreparedStatement empStmt = null;
            PreparedStatement memStmt = null;
            ResultSet empRs = null;
            ResultSet memRs = null;

            try {
        %>

        <!-- CARD 1: EMPLOYEES -->
        <div class="card">
            <div class="card-header">
                <div>
                    <h2>Employees Roster</h2>
                    <p class="subtitle">All registered staff members and their system administrative roles.</p>
                </div>
            </div>

            <div class="table-scroll">
                <table id="employeesTable">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Username</th>
                            <th>Admin</th>
                            <th>Coach</th>
                            <th>Status</th>
                            <th colspan="2">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            String empQuery = "SELECT u.user_id, u.first_name, u.last_name, u.user_name, u.active_flag, e.coach_flag, e.admin_flag " +
                                              "FROM users u JOIN employees e ON u.user_id = e.user_id WHERE u.user_type = 0";
                            empStmt = con.prepareStatement(empQuery);
                            empRs = empStmt.executeQuery();

                            while(empRs.next()) {
                                boolean isActive = empRs.getInt("active_flag") == 1;
                        %>
                        <tr class="user-row">
                            <td><%= empRs.getInt("user_id") %></td>
                            <td><%= empRs.getString("first_name") %> <%= empRs.getString("last_name") %></td>
                            <td><%= empRs.getString("user_name") %></td>
                            <td><%= empRs.getInt("admin_flag") == 1 ? "Yes" : "No" %></td>
                            <td><%= empRs.getInt("coach_flag") == 1 ? "Yes" : "No" %></td>
                            <td>
                                <span class="badge <%= isActive ? "badge-employee" : "badge-muted" %>">
                                    <%= isActive ? "Active" : "Inactive" %>
                                </span>
                            </td>
                            <td>
                                <!-- Employee Deactivate/Reactivate Button -->
                                <% if (isActive) { %>
                                <form action="users.jsp" method="post" class="inline-form">
                                    <input type="hidden" name="target_user_id" value="<%= empRs.getInt("user_id") %>" />
                                    <input type="hidden" name="user_action" value="deactivate" />
                                    <button type="submit" class="btn btn-danger btn-sm" onclick="return confirm('Deactivate this employee?');">Deactivate</button>
                                </form>
                                <% } else { %>
                                <form action="users.jsp" method="post" class="inline-form">
                                    <input type="hidden" name="target_user_id" value="<%= empRs.getInt("user_id") %>" />
                                    <input type="hidden" name="user_action" value="activate" />
                                    <button type="submit" class="btn btn-secondary btn-sm" onclick="return confirm('Reactivate this employee?');">Activate</button>
                                </form>
                                <% } %>
                            </td>
                            <td>
                                <!-- Employee Update Button -->
                                <form action="update-employee.jsp" method="get" class="inline-form">
                                    <input id="user_id" name="user_id" type="hidden" value="<%= empRs.getInt("user_id") %>" />
					<button type="submit" class="btn btn-secondary btn-sm">Update</button>
                                </form>
                            </td>
                        </tr>
                        <%  } %>
                    </tbody>
                </table>
            </div>
        </div>

        <!-- CARD 2: MEMBERS -->
        <div class="card">
            <div class="card-header">
                <div>
                    <h2>Members Roster</h2>
                    <p class="subtitle">All registered members, training goals, and membership statuses.</p>
                </div>
            </div>

            <div class="table-scroll">
                <table id="membersTable">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Name</th>
                            <th>Username</th>
                            <th>Goals</th>
                            <th>Health Notes</th>
                            <th>Status</th>
                            <th colspan="2">Action</th>
                        </tr>
                    </thead>
                    <tbody>
                        <%
                            String memQuery = "SELECT u.user_id, u.first_name, u.last_name, u.user_name, u.active_flag, m.goals, m.health_notes " +
                                              "FROM users u JOIN members m ON u.user_id = m.user_id WHERE u.user_type = 1";
                            memStmt = con.prepareStatement(memQuery);
                            memRs = memStmt.executeQuery();

                            while(memRs.next()) {
                                boolean isActive = memRs.getInt("active_flag") == 1;
                        %>
                        <tr class="user-row">
                            <td><%= memRs.getInt("user_id") %></td>
                            <td><%= memRs.getString("first_name") %> <%= memRs.getString("last_name") %></td>
                            <td><%= memRs.getString("user_name") %></td>
                            <td><%= memRs.getString("goals") != null ? memRs.getString("goals") : "None" %></td>
                            <td><%= memRs.getString("health_notes") != null ? memRs.getString("health_notes") : "None" %></td>
                            <td>
                                <span class="badge <%= isActive ? "badge-member" : "badge-muted" %>">
                                    <%= isActive ? "Active" : "Inactive" %>
                                </span>
                            </td>
                            <td>
                                <!-- Member Deactivate/Reactivate Button -->
                                <% if (isActive) { %>
                                <form action="users.jsp" method="post" class="inline-form">
                                    <input type="hidden" name="target_user_id" value="<%= memRs.getInt("user_id") %>" />
                                    <input type="hidden" name="user_action" value="deactivate" />
                                    <button type="submit" class="btn btn-danger btn-sm" onclick="return confirm('Deactivate this member?');">Deactivate</button>
                                </form>
                                <% } else { %>
                                <form action="users.jsp" method="post" class="inline-form">
                                    <input type="hidden" name="target_user_id" value="<%= memRs.getInt("user_id") %>" />
                                    <input type="hidden" name="user_action" value="activate" />
                                    <button type="submit" class="btn btn-secondary btn-sm" onclick="return confirm('Reactivate this member?');">Activate</button>
                                </form>
                                <% } %>
                            </td>
                             <td>
                                <!-- Member Update Button -->
                                <form action="update-member.jsp" method="get" class="inline-form">
                                    <input id="user_id" name="user_id" type="hidden" value="<%= memRs.getInt("user_id") %>" />
					<button type="submit" class="btn btn-secondary btn-sm">Update</button>
                                </form>
                            </td>
                        </tr>
                        <%  } %>
                    </tbody>
                </table>
            </div>
        </div>

        <%
            } catch (Exception e) {
                out.println("<div class='card'><p class='message message-error'>Error loading users: " + e.getMessage() + "</p></div>");
            } finally {
                if (empRs != null) try { empRs.close(); } catch (SQLException ignore) {}
                if (memRs != null) try { memRs.close(); } catch (SQLException ignore) {}
                if (empStmt != null) try { empStmt.close(); } catch (SQLException ignore) {}
                if (memStmt != null) try { memStmt.close(); } catch (SQLException ignore) {}
                try { con.close(); } catch (SQLException ignore) {}
            }
        %>
    </main>

    <!-- REAL-TIME SEARCH SCRIPT -->
    <script>
        function filterUsers() {
            var input = document.getElementById("userSearchInput");
            var filter = input.value.toLowerCase();
            var rows = document.getElementsByClassName("user-row");

            for (var i = 0; i < rows.length; i++) {
                var rowText = rows[i].textContent || rows[i].innerText;
                if (rowText.toLowerCase().indexOf(filter) > -1) {
                    rows[i].style.display = "";
                } else {
                    rows[i].style.display = "none";
                }
            }
        }
    </script>
</body>
</html>
