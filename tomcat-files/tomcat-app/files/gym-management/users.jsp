<%@ page import="java.sql.*, javax.naming.*, javax.sql.DataSource" %>
<%@ include file="/WEB-INF/includes/auth-check.jspf" %>
<%
    if (auth_admin_flag != 1) {
        response.sendRedirect("/tomcat-app/gym-management/");
        return;
    }

    String active_page = "users";
    if (request.getMethod().equals("POST") && (con != null)) {
	try {
	    int delete_user_id = Integer.parseInt(
		request.getParameter("delete_user_id"));
	    int delete_user_type = Integer.parseInt(
		request.getParameter("delete_user_type"));
	    con.setAutoCommit(false);
	    try {
		String deluser1_sql = "DELETE FROM users "
		+ "WHERE user_id = ? AND user_type = ?";
		PreparedStatement deluser1_stmt =
		con.prepareStatement(deluser1_sql);
		deluser1_stmt.setInt(1, delete_user_id);
		deluser1_stmt.setInt(2, delete_user_type);
		deluser1_stmt.executeUpdate();
		deluser1_stmt.close();
		String deluser2_sql;
		if (delete_user_type == 0)
		deluser2_sql = "DELETE FROM employees WHERE user_id = ?";
		else
		deluser2_sql = "DELETE FROM members WHERE user_id = ?";
		PreparedStatement deluser2_stmt =
		con.prepareStatement(deluser2_sql);
		deluser2_stmt.setInt(1, delete_user_id);
		deluser2_stmt.executeUpdate();
		deluser2_stmt.close();
		con.commit();
	    } catch(SQLException e) {
		con.rollback();
	    }
	    con.setAutoCommit(true);
	} catch (Exception e) {
	}
	response.sendRedirect("users.jsp");
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
                    <p class="subtitle">Search and filter active employees and members registered in the system.</p>
                    <div style="margin-top: 16px;">
                        <input type="text" id="userSearchInput" onkeyup="filterUsers()" placeholder="Search by name, username, ID, or goals..." style="width: 100%; padding: 12px; font-size: 0.95rem; border: 1px solid var(--color-border); border-radius: 8px;">
                    </div>
                </div>
            </div>
        </div>

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
                            <th></th>
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
                        <tr class="user-row">
                            <td><%= empRs.getInt("user_id") %></td>
                            <td><%= empRs.getString("first_name") %> <%= empRs.getString("last_name") %></td>
                            <td><%= empRs.getString("user_name") %></td>
                            <td><%= empRs.getInt("admin_flag") == 1 ? "Yes" : "No" %></td>
                            <td><%= empRs.getInt("coach_flag") == 1 ? "Yes" : "No" %></td>
                            <td>
				<form action="users.jsp" method="post"
				      class="inline_form">
				    <input type="hidden"
					   name="delete_user_type"
					   value="0" />
				    <input type="hidden"
					   name="delete_user_id"
					   value="<%= empRs.getInt("user_id") %>"
				    />
				    <button type="submit"
					    class="btn btn-danger btn-sm"
					    onclick="return confirm(
					'Delete this employee?');">Delete</button>
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
                            <th></th>
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
                        <tr class="user-row">
                            <td><%= memRs.getInt("user_id") %></td>
                            <td><%= memRs.getString("first_name") %> <%= memRs.getString("last_name") %></td>
                            <td><%= memRs.getString("user_name") %></td>
                            <td><%= memRs.getString("goals") != null ? memRs.getString("goals") : "None" %></td>
                            <td><%= memRs.getString("health_notes") != null ? memRs.getString("health_notes") : "None" %></td>
                            <td>
                                <span class="badge <%= memRs.getInt("active_flag") == 1 ? "badge-member" : "badge-muted" %>">
                                    <%= memRs.getInt("active_flag") == 1 ? "Active" : "Inactive" %>
                                </span>
                            </td>
                            <td>
				<form action="users.jsp" method="post"
				      class="inline_form">
				    <input type="hidden"
					   name="delete_user_type"
					   value="1" />
				    <input type="hidden"
					   name="delete_user_id"
					   value="<%= memRs.getInt("user_id") %>"
				    />
				    <button type="submit"
					    class="btn btn-danger btn-sm"
					    onclick="return confirm(
					'Delete this member?');">Delete</button>
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
                if (conn != null) try { conn.close(); } catch (SQLException ignore) {}
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
